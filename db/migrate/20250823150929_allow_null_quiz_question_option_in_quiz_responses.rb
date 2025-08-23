class AllowNullQuizQuestionOptionInQuizResponses < ActiveRecord::Migration[8.0]
  def change
    # Allow quiz_question_option_id to be null for short answer questions
    change_column_null :quiz_responses, :quiz_question_option_id, true
  end
end
