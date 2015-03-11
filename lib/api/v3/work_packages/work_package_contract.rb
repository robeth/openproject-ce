#-- encoding: UTF-8
#-- copyright
# OpenProject is a project management system.
# Copyright (C) 2012-2015 the OpenProject Foundation (OPF)
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License version 3.
#
# OpenProject is a fork of ChiliProject, which is a fork of Redmine. The copyright follows:
# Copyright (C) 2006-2013 Jean-Philippe Lang
# Copyright (C) 2010-2013 the ChiliProject Team
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#
# See doc/COPYRIGHT.rdoc for more details.
#++

module API
  module V3
    module WorkPackages
      class WorkPackageContract < ::API::Contracts::ModelContract
        writable_attribute :subject
        writable_attribute :description
        writable_attribute :start_date
        writable_attribute :due_date
        writable_attribute :status_id
        writable_attribute :priority_id
        writable_attribute :category_id
        writable_attribute :fixed_version_id

        writable_attribute :lock_version do
          errors.add :error_conflict, '' if model.lock_version.nil? || model.lock_version_changed?
        end

        writable_attribute :parent_id do
          if model.changed.include? 'parent_id'
            errors.add :error_unauthorized, '' unless @can.allowed?(model, :manage_subtasks)
          end
        end

        writable_attribute :assigned_to_id do
          validate_people_visible :assignee,
                                  'assigned_to_id',
                                  model.project.possible_assignee_members
        end

        writable_attribute :responsible_id do
          validate_people_visible :responsible,
                                  'responsible_id',
                                  model.project.possible_responsible_members
        end

        def initialize(object, user)
          super(object)

          @user = user
          @can = WorkPackagePolicy.new(user)
        end

        validate :user_allowed_to_access
        validate :user_allowed_to_edit

        extend Reform::Form::ActiveModel::ModelValidations
        copy_validations_from WorkPackage

        private

        # TODO: when someone every fixes the way errors are added in the contract:
        # find a solution to ensure that THIS validation supersedes others (i.e. show 404 if
        # there is no access allowed)
        def user_allowed_to_access
          unless ::WorkPackage.visible(@user).exists?(model)
            errors.add :error_not_found, I18n.t('api_v3.errors.code_404')
          end
        end

        def user_allowed_to_edit
          errors.add :error_unauthorized, '' unless @can.allowed?(model, :edit)
        end

        def validate_people_visible(attribute, id_attribute, list)
          id = model[id_attribute]

          return if id.nil? || !model.changed.include?(id_attribute)

          unless principal_visible?(id, list)
            errors.add attribute,
                       I18n.t('api_v3.errors.validation.invalid_user_assigned_to_work_package',
                              property: I18n.t("attributes.#{attribute}"))
          end
        end

        def principal_visible?(id, list)
          list.exists?(user_id: id)
        end
      end
    end
  end
end
