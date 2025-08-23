require "test_helper"

class CoursesControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get courses_index_url
    assert_response :success
  end

  test "should get show" do
    get courses_show_url
    assert_response :success
  end

  test "should get enroll" do
    get courses_enroll_url
    assert_response :success
  end

  test "should get complete_step" do
    get courses_complete_step_url
    assert_response :success
  end
end
