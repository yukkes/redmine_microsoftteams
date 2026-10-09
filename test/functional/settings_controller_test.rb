# frozen_string_literal: true

require File.expand_path('../test_helper', __dir__)

class SettingsControllerTest < Redmine::ControllerTest
  tests SettingsController

  fixtures :users, :email_addresses

  def setup
    @request.session[:user_id] = 1
  end

  def test_plugin_settings
    with_settings plugin_redmine_microsoftteams: { 'teams_url' => 'https://example.com/teams',
                                                   'display_watchers' => 'yes', 'post_updates' => '1',
                                                   'webhook_role' => 'Manager' } do
      get :plugin, params: { id: 'redmine_microsoftteams' }
    end

    assert_response :success
    assert_select 'input[name=?][value=?]', 'settings[teams_url]', 'https://example.com/teams'
    assert_select 'select[name=?] option[selected=selected]', 'settings[display_watchers]', text: 'Yes'
    assert_select 'input[name=?][checked=checked]', 'settings[post_updates]'
    assert_select 'input[name=?]:not([checked])', 'settings[post_wiki_updates]'
    assert_select 'input[name=?][value=?]', 'settings[webhook_role]', 'Manager'
  end

  def test_plugin_settings_defaults
    with_settings plugin_redmine_microsoftteams: {} do
      get :plugin, params: { id: 'redmine_microsoftteams' }
    end

    assert_response :success
    assert_select 'select[name=?] option[selected=selected]', 'settings[display_watchers]', text: 'No'
    assert_select 'input[name=?]:not([checked])', 'settings[post_updates]'
  end

  def test_save_plugin_settings
    post :plugin, params: { id: 'redmine_microsoftteams',
                            settings: { teams_url: 'https://example.com/saved', post_updates: '1' } }

    assert_response :redirect
    assert_equal 'https://example.com/saved', Setting.plugin_redmine_microsoftteams['teams_url']
    assert_equal '1', Setting.plugin_redmine_microsoftteams['post_updates']
  end
end
