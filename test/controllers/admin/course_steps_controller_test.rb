require "test_helper"

class Admin::CourseStepsControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get admin_course_steps_index_url
    assert_response :success
  end

  test "should get new" do
    get admin_course_steps_new_url
    assert_response :success
  end

  test "should get create" do
    get admin_course_steps_create_url
    assert_response :success
  end

  test "should get edit" do
    get admin_course_steps_edit_url
    assert_response :success
  end

  test "should get update" do
    get admin_course_steps_update_url
    assert_response :success
  end

  test "should get destroy" do
    get admin_course_steps_destroy_url
    assert_response :success
  end

  test "should get move_up" do
    get admin_course_steps_move_up_url
    assert_response :success
  end

  test "should get move_down" do
    get admin_course_steps_move_down_url
    assert_response :success
  end
end
