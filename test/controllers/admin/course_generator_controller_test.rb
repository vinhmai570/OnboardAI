require "test_helper"

class Admin::CourseGeneratorControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get admin_course_generator_index_url
    assert_response :success
  end

  test "should get generate" do
    get admin_course_generator_generate_url
    assert_response :success
  end
end
