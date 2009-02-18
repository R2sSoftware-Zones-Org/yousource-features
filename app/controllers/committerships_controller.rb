#--
#   Copyright (C) 2009 Johan Sørensen <johan@johansorensen.com>
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

class CommittershipsController < ApplicationController
  before_filter :find_repository_owner, :except => [:auto_complete_for_group_name]
  before_filter :find_repository, :except => [:auto_complete_for_group_name]
  before_filter :require_adminship, :except => [:auto_complete_for_group_name]
  
  def index
    @committerships = @repository.committerships.paginate(:all, :page => params[:page])
    @root = Breadcrumb::Committerships.new(@repository)
  end
  
  def new
    @committership = @repository.committerships.new
  end
  
  def create
    @committership = @repository.committerships.new
    @committership.committer = Group.find_by_name(params[:group][:name])
    @committership.creator = current_user
    
    if @committership.save
      flash[:success] = "Team added as committers"
      redirect_to([@owner, @repository, :committerships])
    else
      render :action => "new"
    end
  end
  
  def destroy
    @committership = @repository.committerships.find(params[:id])
    if @committership.destroy
      flash[:notice] = "The team was removed as a committer"
    end
    redirect_to([@owner, @repository, :committerships])
  end
  
  def auto_complete_for_group_name
    @groups = Group.find(:all, 
      :conditions => [ 'LOWER(name) LIKE ?', '%' + params[:group][:name].downcase + '%' ],
      :limit => 10)
    render :layout => false
  end
  
  protected
    def require_adminship
      unless @owner.admin?(current_user)
        respond_to do |format|
          format.html { 
            flash[:error] = I18n.t "repositories_controller.adminship_error"
            redirect_to([@owner, @repository]) 
          }
          format.xml  { 
            render :text => I18n.t( "repositories_controller.adminship_error"), 
                    :status => :forbidden 
          }
        end
        return
      end
    end
    
    def find_repository
      @repository = @owner.repositories.find_by_name!(params[:repository_id])
    end
end