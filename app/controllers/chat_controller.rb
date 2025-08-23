class ChatController < ApplicationController
  def create
    message = params[:message]
    course_id = params[:course_id]

    # Get relevant document chunks for context
    context_chunks = []

    if course_id.present?
      course = Course.find(course_id)
      # For now, just use a simple response
      response = "I'm here to help with your course: #{course.title}. What would you like to know?"
    else
      response = "Hello! I'm your OnboardAI assistant. How can I help you today?"
    end

    # Use OpenAI for real responses (commented out for demo)
    # response = OpenaiService.chat_response(message, context_chunks)

    render json: { response: response }
  end
end
