require 'gitlab'

module GitlabInt
  module GitlabMethods
    def gitlab_create(attrs)
      gitlab = gitlab_configure
      visibility = attrs[:visibility].to_i * 10
      project = gitlab.create_project(attrs[:title], description: attrs[:description], visibility_level: visibility)
      gitlab.transfer_project_to_group(attrs[:group], project.id)
      gitlab.project(project.id)
    end

    def gitlab_create_group(attrs)
      gitlab_configure.create_group(attrs[:title], attrs[:identifier]).id
    end

    def gitlab_member_and_group(attrs)
      operations =  {
                      add:    ->(gid, uid, rid) { gitlab_configure.add_group_member(gid, uid, rid) },
                      remove: ->(gid, uid, _)   { gitlab_configure.remove_group_member(gid, uid) },
                      edit:   ->(gid, uid, rid) { 
                                                  gitlab_configure.remove_group_member(gid, uid)
                                                  gitlab_configure.add_group_member(gid, uid, rid)
                                                }
                    }
      role = attrs[:role] ? Setting.plugin_redmine_gitlab_integration['gitlab_role']["#{attrs[:role]}"] : 50
      user = gitlab_configure(attrs[:token]).user
      begin
        operations[attrs[:op]].call(attrs[:group], user.id, role)
      rescue
        # Redmine removes member twice, so it causes error
      end
    end

    def gitlab_destroy(attrs)
      gitlab = gitlab_configure
      gitlab.delete_project(attrs[:id])
    end

    def gitlab_destroy_all(attrs)
      gitlab = gitlab_configure
      projects = gitlab.projects.map(&:to_h)
      projects.each do |p|
        gitlab.delete_project(p['id'])
      end
    end

    def gitlab_get_members(options = {})
      gitlab = gitlab_configure
      gitlab.team_members(options[:id])
    end

    def gitlab_add_members(options = {})
      options[:members].each do |m|
        gitlab_member_and_group({ group: options[:group], op: :add, token: m[:token], role: m[:role] })
      end
    end

    def gitlab_token_valid?(token)
      begin
        gitlab_configure(token).user
      rescue
        false
      end
    end

    def gitlab_configure(token = nil)
      token ||= Setting.plugin_redmine_gitlab_integration['gitlab_bot']
      Gitlab.client(endpoint: get_gitlab_url, private_token: token)
    end

    def gitlab_get_user(login)
      user = User.where(login: login).first
      gitlab = Gitlab.client(endpoint: get_gitlab_url, private_token: user.gitlab_token)
      gitlab.user
    end

    private
    def get_gitlab_url
      Setting.plugin_redmine_gitlab_integration['gitlab_url'] + '/api/v3'
    end
  end
end
