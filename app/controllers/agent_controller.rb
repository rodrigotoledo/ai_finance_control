# app/controllers/agent_controller.rb
class AgentController < ApplicationController
  before_action :authenticate_user!
  
  def chat
    @active_session = current_user.agent_sessions.active.last || 
                      current_user.agent_sessions.create
  end
  
  def ask
    session = current_user.agent_sessions.find(params[:session_id])
    user_message = params[:message]
    
    # Adiciona a mensagem e processa
    AgentOrchestratorJob.perform_later(session.id, user_message)
    
    redirect_to agent_chat_path(session_id: session.id), 
                notice: "Processando sua pergunta..."
  end
  
  def history
    @sessions = current_user.agent_sessions.order(created_at: :desc).limit(20)
  end
  
  def session_messages
    @session = current_user.agent_sessions.find(params[:id])
    @messages = @session.messages.order(:created_at)
    
    render partial: 'messages', locals: { messages: @messages }
  end
end