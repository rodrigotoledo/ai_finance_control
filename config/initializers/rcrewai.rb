require 'rcrewai'

RCrewAI.configure do |config|
  config.llm_provider = :openai
  config.openai_api_key = ENV['OPENAI_API_KEY']
  config.temperature = 0.1
end
