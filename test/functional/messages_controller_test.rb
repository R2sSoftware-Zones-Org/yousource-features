# encoding: utf-8
#--
#   Copyright (C) 2008-2009 Marius Mathiesen <marius.mathiesen@gmail.com>
#
#   This program is free software: you can redistribute it and/or modify
#   it under the terms of the GNU Affero General Public License as published by
#   the Free Software Foundation, either version 3 of the License, or
#   (at your option) any later version.
#
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU Affero General Public License for more details.
#
#   You should have received a copy of the GNU Affero General Public License
#   along with this program.  If not, see <http://www.gnu.org/licenses/>.
#++
require File.dirname(__FILE__) + '/../test_helper'

class MessagesControllerTest < ActionController::TestCase
  context 'On GET to index' do
    setup do
      login_as :moe
      get :index
    end
    
    should_respond_with :success
    should_assign_to :messages
    should_render_template :index
  end
  
  context 'On GET to sent' do
    setup do
      login_as :moe
      get :sent
    end
    
    should_respond_with :success
    should_assign_to :messages
    should_render_template :sent
  end
  
  context 'On GET to show' do
    setup do 
      @message = messages(:johans_message_to_moe)
      login_as :moe
      get :show, :id => @message.to_param
    end
    
    should_respond_with :success
    should_assign_to :message
  end

  context 'Trying to peek at other peoples messages' do
    setup do
      login_as :mike
      get :show, :id => @message.to_param
    end
    
    should_respond_with :not_found
  end
  
  context 'On PUT to read' do
    setup do
      login_as :moe
      @message = messages(:johans_message_to_moe)
      put :read, :id => @message.to_param, :format => 'js'
    end
    
    should_respond_with :success
    should_assign_to :message#, @message)
  end
  
  context 'On POST to create' do
    setup do
      login_as :moe 
      post :create, :message => {:subject => "Hello", :body => "Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum."}, :recipient => {:login => "johan"}
    end
    
    should_respond_with :redirect
    should_assign_to :message
    should_set_the_flash_to(/sent/i)
  end
  
  context 'On POST to reply' do # POST /messages/2/reply
    setup do
      login_as :moe
      @original_message = messages(:johans_message_to_moe)
      post :reply, :id => @original_message.to_param, :message => {:body => "Yeah, great idea", :subject => "Well"}
    end
    
    should_assign_to :message
    should_respond_with :redirect
    should_set_the_flash_to(/sent/i)
    
    should 'set the correct subject' do
      result = assigns(:message)
      assert_equal("Well", result.subject)
    end
  end
  
  context 'On GET to new' do
    setup do
      login_as :johan
      get :new
    end
    
    should_assign_to :message
    should_respond_with :success
    should_render_template :new
  end
  
  context 'On POST to auto_complete_for_recipient_login' do
    setup do
      login_as :johan
      post :auto_complete_for_recipient_login, :recipient => {:login => "joh"}, :format => "js"
    end

    should 'assign an array of users' do
      assert_equal([users(:johan)], assigns(:users))
    end
  end
  
  context 'Unauthenticated GET to index' do
    setup {get :index}
    
    should_respond_with :redirect
  end
end