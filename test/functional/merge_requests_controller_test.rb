# encoding: utf-8
#--
#		Copyright (C) 2008-2009 Johan Sørensen <johan@johansorensen.com>
#		Copyright (C) 2008 Tim Dysinger <tim@dysinger.net>
#		Copyright (C) 2009 Marius Mathiesen <zmalltalker@gmail.com>
#
#		This program is free software: you can redistribute it and/or modify
#		it under the terms of the GNU Affero General Public License as published by
#		the Free Software Foundation, either version 3 of the License, or
#		(at your option) any later version.
#
#		This program is distributed in the hope that it will be useful,
#		but WITHOUT ANY WARRANTY; without even the implied warranty of
#		MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.	See the
#		GNU Affero General Public License for more details.
#
#		You should have received a copy of the GNU Affero General Public License
#		along with this program.	If not, see <http://www.gnu.org/licenses/>.
#++


require File.dirname(__FILE__) + '/../test_helper'

class MergeRequestsControllerTest < ActionController::TestCase
  
	def setup
		@project = projects(:johans)
		git = mock
		git.stubs(:branches).returns([])
		Repository.any_instance.stubs(:git).returns(git)
		@source_repository = repositories(:johans2)
		@target_repository = repositories(:johans)
		@merge_request = merge_requests(:moes_to_johans)
		@merge_request.stubs(:commits_for_selection).returns([])
	end
	
	context "#index (GET)" do		
		should " not require login" do
			session[:user_id] = nil
			get :index, :project_id => @project.to_param,
				:repository_id => @target_repository.to_param
			assert_response :success
		end
		
		should "gets all the merge requests in the repository" do
			get :index, :project_id => @project.to_param,
				:repository_id => @target_repository.to_param
			assert_equal @target_repository.merge_requests, assigns(:merge_requests)
		end
		
		should "gets a comment count for" do
			get :index, :project_id => @project.to_param,
				:repository_id => @target_repository.to_param
			assert_equal @target_repository.comments.count, assigns(:comment_count)
		end
	end
	
	context "#show (GET)" do		
		should " not require login" do
			session[:user_id] = nil
			MergeRequest.expects(:find).returns(@merge_request)
			[@merge_request.source_repository, @merge_request.target_repository].each do |r|
				r.stubs(:git).returns(stub_everything("Git"))
			end
			get :show, :project_id => @project.to_param, 
				:repository_id => @target_repository.to_param,
				:id => @merge_request.id
			assert_response :success
		end
		
		should "gets a list of the commits to be merged" do
			MergeRequest.expects(:find).returns(@merge_request)
      commits = %w(9dbb89110fc45362fc4dc3f60d960381 6823e6622e1da9751c87380ff01a1db1 526fa6c0b3182116d8ca2dc80dedeafb 286e8afb9576366a2a43b12b94738f07).collect do |sha|
	      m = mock
	      m.stubs(:id).returns(sha)
	      m.stubs(:id_abbrev).returns(sha[0..7])
	      m.stubs(:committer).returns(Grit::Actor.new("bob", "bob@example.com"))
	      m.stubs(:author).returns(Grit::Actor.new("bob", "bob@example.com"))
	      m.stubs(:message).returns("bla bla")
	      m.stubs(:committed_date).returns(3.days.ago)
	      m
      end
      @merge_request.stubs(:commits_for_selection).returns(commits)
			get :show, :project_id => @project.to_param, 
				:repository_id => @target_repository.to_param,
				:id => @merge_request.id
			assert_equal 4, assigns(:commits).size
		end
		
		should "allow committers to change status" do
		  login_as :johan
  		@project = projects(:johans)
  		@project.owner = groups(:team_thunderbird)
  		@project.owner.add_member(users(:johan), Role.committer)
  		@repository = repositories(:johans2)
  		@mainline_repository = repositories(:johans)
  		@merge_request = merge_requests(:moes_to_johans)
  		
  		MergeRequest.expects(:find).returns(@merge_request)
  		git_stub = stub_everything("Grit", :commit_deltas_from => [])
  		[@merge_request.source_repository, @merge_request.target_repository].each do |r|
  			r.stubs(:git).returns(git_stub)
  		end
  		get :show, :project_id => @project.to_param, 
  			:repository_id => repositories(:johans).name,
  			:id => @merge_request.id
  		assert_match(/Update merge request/, @response.body) #TODO assert_select proper
    end
	end

	context "#new (GET)" do
	  setup do
	    Grit::Repo.any_instance.stubs(:heads).returns([])
    end
    
		should "requires login" do
			session[:user_id] = nil
			get :new, :project_id => @project.to_param, 
				:repository_id => @source_repository.to_param
			assert_redirected_to(new_sessions_path)
		end
		
		should "is successful" do
			login_as :johan
			get :new, :project_id => @project.to_param, 
				:repository_id => @source_repository.to_param
			assert_response :success
		end
		
		should "assigns the new merge_requests' source_repository" do
			login_as :johan
			get :new, :project_id => @project.to_param, 
				:repository_id => @source_repository.to_param
			assert_equal @source_repository, assigns(:merge_request).source_repository
		end
		
		should "gets a list of possible target clones" do
			login_as :johan
			get :new, :project_id => @project.to_param, 
				:repository_id => @source_repository.to_param
			assert_equal [repositories(:johans)], assigns(:repositories)
		end
	end
	
	def do_post(data={})
		post :create, :project_id => @project.to_param, 
			:repository_id => @source_repository.to_param, :merge_request => {
				:target_repository_id => @target_repository.id,
				:ending_commit => '6823e6622e1da9751c87380ff01a1db1'
			}.merge(data)
	end
	
	context "#create (POST)" do
	  setup do
	    Grit::Repo.any_instance.stubs(:heads).returns([])
    end
    
		should "requires login" do
			session[:user_id] = nil
			do_post
			assert_redirected_to(new_sessions_path)
		end
		
		should "scopes to the source_repository" do
			login_as :johan
			do_post
			assert_equal @source_repository, assigns(:merge_request).source_repository
		end
		
		should "scopes to the current_user" do
			login_as :johan
			do_post
			assert_equal users(:johan), assigns(:merge_request).user
		end
		
		should "creates the record on successful data" do
			login_as :johan
			assert_difference("MergeRequest.count") do
				do_post
				assert_redirected_to(project_repository_path(@project, @source_repository))
				assert_match(/sent a merge request to "#{@target_repository.name}"/i, flash[:success])
      end
		end
		
		should "it re-renders on invalid data, with the target repos list" do
			login_as :johan
			do_post :target_repository => nil
			assert_response :success
			assert_template(("merge_requests/new"))
			assert_equal [repositories(:johans)], assigns(:repositories)
		end
	end
	
	context "#edit (GET)" do		
		should "requires login" do
			session[:user_id] = nil
			get :edit, :project_id => @project.to_param, :repository_id => @target_repository.to_param,
				:id => @merge_request
			assert_redirected_to(new_sessions_path)
		end
		
		should "requires ownership to edit" do
			login_as :moe
			get :edit, :project_id => @project.to_param, :repository_id => @target_repository.to_param,
				:id => @merge_request
			assert_match(/you're not the owner/i, flash[:error])
			assert_response :redirect
		end
		
		should "is successfull" do
			login_as :johan
			get :edit, :project_id => @project.to_param, :repository_id => @target_repository.to_param,
				:id => @merge_request
			assert_response :success
		end
		
		should "gets a list of possible target clones" do
			login_as :johan
			get :edit, :project_id => @project.to_param, :repository_id => @target_repository.to_param,
				:id => @merge_request
			assert_equal [@source_repository], assigns(:repositories)
		end
	end
	
	def do_put(data={})
		put :update, :project_id => @project.to_param, 
			:repository_id => @target_repository.to_param, 
			:id => @merge_request,
			:merge_request => {
				:target_repository_id => @target_repository.id,
			}.merge(data)
	end
	
	context "#update (PUT)" do		
		should "requires login" do
			session[:user_id] = nil
			do_put
			assert_redirected_to(new_sessions_path)
		end
		
		should "requires ownership to update" do
			login_as :moe
			do_put
			assert_match(/you're not the owner/i, flash[:error])
			assert_response :redirect
		end
		
		should "scopes to the source_repository" do
			login_as :johan
			do_put
			assert_equal @source_repository, assigns(:merge_request).source_repository
		end
		
		should "scopes to the current_user" do
			login_as :johan
			do_put
			assert_equal users(:johan), assigns(:merge_request).user
		end
		
		should "updates the record on successful data" do
			login_as :johan
			do_put :proposal => "hai, plz merge kthnkxbye"
			
			assert_redirected_to(project_repository_merge_request_path(@project, @target_repository, @merge_request))
			assert_match(/merge request was updated/i, flash[:success])
			assert_equal "hai, plz merge kthnkxbye", @merge_request.reload.proposal
		end
		
		should "it re-renders on invalid data, with the target repos list" do
			login_as :johan
			do_put :target_repository => nil
			assert_response :success
			assert_template(("merge_requests/edit"))
			assert_equal [@source_repository], assigns(:repositories)
		end
		
		should "only allows the owner to update" do
			login_as :moe
			do_put
			assert_no_difference("MergeRequest.count") do
				assert_redirected_to(project_repository_path(@project, @target_repository))
				assert_equal nil, flash[:success]
				assert_match(/You're not the owner of this merge request/i, flash[:error])
      end
		end
	end
	
	def do_resolve_put(data={})
		put :resolve, :project_id => @project.to_param, 
			:repository_id => @target_repository.to_param, 
			:id => @merge_request,
			:merge_request => {
				:status => MergeRequest::STATUS_MERGED,
			}.merge(data)
	end
	
	context "#resolve (PUT)" do		
		should "requires login" do
			session[:user_id] = nil
			do_resolve_put
			assert_redirected_to(new_sessions_path)
		end
		
		should "requires ownership to resoble" do
			login_as :moe
			do_resolve_put
			assert_match(/you're not permitted/i, flash[:error])
			assert_response :redirect
		end
		
		should "updates the status" do
			login_as :johan
			do_resolve_put
			assert_equal "The merge request was marked as merged", flash[:notice]
			assert_response :redirect
		end
	end
	
	context "#get commit_list" do
	  setup do
	    @commits = %w(ffcffcffc ff0ff0ff0).collect do |sha|
	      m = mock
	      m.stubs(:id).returns(sha)
	      m.stubs(:id_abbrev).returns(sha[0..7])
	      m.stubs(:committer).returns(Grit::Actor.new("bob", "bob@example.com"))
	      m.stubs(:author).returns(Grit::Actor.new("bob", "bob@example.com"))
	      m.stubs(:message).returns("bla bla")
	      m.stubs(:committed_date).returns(3.days.ago)
	      m
      end
	    merge_request = MergeRequest.new
	    merge_request.stubs(:commits_for_selection).returns(@commits)
	    MergeRequest.expects(:new).returns(merge_request)
    end
    
	  should " render a list of commits that can be merged" do
	    login_as :johan
			get :commit_list, :project_id => @project.to_param, 
				:repository_id => @target_repository.to_param,
				:merge_request => {}
			assert_equal @commits, assigns(:commits)
    end
  end
	
	def do_delete
		delete :destroy, :project_id => @project.to_param, 
			:repository_id => @target_repository.to_param, 
			:id => @merge_request
	end
	
	context "#destroy (DELETE)" do		
		should "requires login" do
			session[:user_id] = nil
			do_delete
			assert_redirected_to(new_sessions_path)
		end
		
		should "scopes to the source_repository" do
			login_as :johan
			do_delete
			assert_equal @source_repository, assigns(:merge_request).source_repository
		end
		
		should "deletes the record" do
			login_as :johan
			do_delete
			assert_redirected_to(project_repository_path(@project, @target_repository))
			assert_match(/merge request was retracted/i, flash[:success])
			assert_nil MergeRequest.find_by_id(@merge_request.id)
		end
		
		should "only allows the owner to delete" do
			login_as :moe
			do_delete
			assert_no_difference("MergeRequest.count") do
				assert_redirected_to(project_repository_path(@project, @target_repository))
				assert_equal nil, flash[:success]
				assert_match(/You're not the owner of this merge request/i, flash[:error])
      end
		end
	end

end