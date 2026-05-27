# app/jobs/agent_orchestrator_job.rb
class AgentOrchestratorJob < ApplicationJob
  queue_as :default
  
  def perform(session_id, user_message = nil)
    session = AgentSession.find(session_id)
    
    # Adiciona mensagem do usuário se houver
    session.add_message(role: 'user', content: user_message) if user_message
    
    # Carrega o contexto financeiro do usuário
    context = build_financial_context(session.user)
    
    # Prepara o prompt do sistema
    system_prompt = <<~PROMPT
      Você é um assistente financeiro pessoal especializado em:
      - Planejamento de aposentadoria
      - Controle de gastos
      - Sugestões de investimento
      
      Contexto do usuário:
      - Renda mensal: R$#{context[:monthly_income]}
      - Economias atuais: R$#{context[:current_savings]}
      - Gastos mensais médios: R$#{context[:avg_monthly_expenses]}
      
      IMPORTANTE: Você NÃO dá conselhos específicos de investimento (ex: "compre ação X").
      Você ajuda com cálculos, estratégias gerais e boas práticas.
      
      Use as ferramentas disponíveis para cálculos financeiros, não faça contas manualmente.
    PROMPT
    
    # Adiciona prompt do sistema se for primeira mensagem
    if session.messages.count == 0
      session.add_message(role: 'system', content: system_prompt)
    end
    
    # Prepara mensagens para a LLM
    messages = session.messages.order(:created_at).map do |msg|
      { role: msg.role, content: msg.content }
    end
    
    # Lista de ferramentas disponíveis
    tools = [
      {
        name: "calculate_retirement",
        description: "Calcula projeção de aposentadoria",
        parameters: {
          type: "object",
          properties: {
            current_age: { type: "integer", description: "Idade atual" },
            retirement_age: { type: "integer", description: "Idade planejada para aposentar" },
            current_savings: { type: "number", description: "Valor já economizado" },
            monthly_contribution: { type: "number", description: "Quanto pode economizar por mês" },
            expected_return: { type: "number", description: "Retorno anual esperado (%)" }
          },
          required: ["current_age", "current_savings", "monthly_contribution"]
        }
      },
      {
        name: "calculate_goal",
        description: "Calcula quanto economizar por mês para atingir uma meta",
        parameters: {
          type: "object",
          properties: {
            target_amount: { type: "number", description: "Valor da meta" },
            current_savings: { type: "number", description: "Quanto já tem" },
            years: { type: "integer", description: "Em quantos anos" },
            expected_return: { type: "number", description: "Retorno anual esperado (%)" }
          },
          required: ["target_amount", "years"]
        }
      }
    ]
    
    # Chama a LLM
    session.pause_for_tool! # Muda status para waiting_for_tool
    
    response = RubyLLM.chat(
      messages: messages,
      tools: tools,
      model: 'gpt-4o-mini',
      temperature: 0.7
    )
    
    # Verifica se a LLM quer usar uma ferramenta
    if response.tool_calls.any?
      tool_call = response.tool_calls.first
      
      result = case tool_call.name
      when "calculate_retirement"
        RetirementTool.calculate(tool_call.arguments)
      when "calculate_goal"
        GoalTool.calculate_needed(tool_call.arguments)
      end
      
      # Adiciona resultado da ferramenta
      session.add_message(
        role: 'tool',
        content: result[:message],
        metadata: { tool_result: result }
      )
      
      # Continua o processamento
      session.process!
      AgentOrchestratorJob.perform_later(session.id)
    else
      # Adiciona resposta final
      session.add_message(role: 'assistant', content: response.content)
      session.complete!
    end
  end
  
  private
  
  def build_financial_context(user)
    transactions = user.transactions.where('date > ?', 3.months.ago)
    total_spent = transactions.sum(:amount)
    
    {
      monthly_income: user.monthly_income || 0,
      current_savings: user.current_savings || 0,
      avg_monthly_expenses: total_spent / 3
    }
  end
end