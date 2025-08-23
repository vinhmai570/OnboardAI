require "test_helper"

class Admin::DocumentsControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get admin_documents_index_url
    assert_response :success
  end

  test "should get new" do
    get admin_documents_new_url
    assert_response :success
  end

  test "should get create" do
    get admin_documents_create_url
    assert_response :success
  end

  test "should get edit" do
    get admin_documents_edit_url
    assert_response :success
  end

  test "should get update" do
    get admin_documents_update_url
    assert_response :success
  end

  test "should get destroy" do
    get admin_documents_destroy_url
    assert_response :success
  end

  test "should get process" do
    get admin_documents_process_url
    assert_response :success
  end
end
