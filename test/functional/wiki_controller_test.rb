# frozen_string_literal: true

require File.expand_path('../test_helper', __dir__)

class WikiControllerTest < Redmine::ControllerTest
  tests WikiController

  fixtures :projects, :users, :email_addresses, :roles, :members, :member_roles,
           :enabled_modules, :wikis, :wiki_pages, :wiki_contents, :wiki_content_versions

  def setup
    @posts = []
    HTTPClient.any_instance.stubs(:post_async).with do |url, body, _headers|
      @posts << { url: url, body: JSON.parse(body) }
    end
    Project.find(1).enable_module!(:microsoftteams)
    @request.session[:user_id] = 2
  end

  def test_post_wiki_update
    with_teams_settings('teams_url' => 'https://example.com/teams') do
      update_page('Changed the page')
    end

    assert_equal 1, @posts.size
    texts = @posts.first[:body]['attachments'].first['content']['body'].pluck('text').compact
    assert(texts.any? do |text|
      text.include?('/projects/ecookbook/wiki/Another_page') && text.include?('Changed the page')
    end)
  end

  def test_post_wiki_update_without_comments_to_legacy_webhook_url
    with_teams_settings('teams_url' => 'https://example.webhook.office.com/webhookb2/teams') do
      update_page('')
    end

    assert_equal 1, @posts.size
    assert_equal 'eCookbook', @posts.first[:body]['title']
    assert_equal '[Another_page](http://localhost:3000/projects/ecookbook/wiki/Another_page) updated by *John Smith*',
                 @posts.first[:body]['text']
  end

  def test_skip_wiki_update_without_url
    with_teams_settings('teams_url' => '') do
      update_page('Changed the page')
    end

    assert_empty @posts
  end

  def test_skip_wiki_update_without_post_wiki_updates
    with_teams_settings('teams_url' => 'https://example.com/teams', 'post_wiki_updates' => '0') do
      update_page('Changed the page')
    end

    assert_empty @posts
  end

  private

  def update_page(comments)
    put :update, params: {
      project_id: 'ecookbook', id: 'Another_page',
      content: { text: 'New text', comments: comments, version: WikiPage.find(2).content.version }
    }
    assert_response :redirect
  end

  def with_teams_settings(settings, &block)
    with_settings(plugin_redmine_microsoftteams: { 'post_wiki_updates' => '1' }.merge(settings), &block)
  end
end
