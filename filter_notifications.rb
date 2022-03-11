require 'octokit'

API_KEY = ENV["API_KEY"]
UNSUBSCRIBE_FILTER_STRINGS = ["grouped deploy branch", "wip"]

PULLS_REGEX = /pulls\/(\d+)/
ISSUES_REGEX = /issues\/(\d+)/
DISCUSSIONS_REGEX = /discussions\/(\d+)/

IGNORE_REPOS = ["github/github"]

client = Octokit::Client.new(access_token: API_KEY)

notifications = client.notifications
puts "📧 #{notifications.count} notifications to process"

notifications.each do |notification|
  notification_title = notification.subject.title.downcase

  # puts "\"#{notification.subject.title}\" from #{notification.repository.full_name}"

  if UNSUBSCRIBE_FILTER_STRINGS.any? { |filter| notification_title.include?(filter) }
    client.mark_thread_as_read(notification.id)
    client.delete_thread_subscription(notification.id)
    puts "unsubscribed from: #{notification.subject.title}"
    next
  end

  if notification.subject.type == "PullRequest"
    url = notification.subject.url
    if url && (match = url.match(PULLS_REGEX))
      id = match.captures.first.to_i
      pr = client.pull_request(notification.repository.full_name, id)

      assignees = pr.assignees.map(&:login)
      requested_reviewers = pr.requested_reviewers.map(&:login)
      requested_teams = pr.requested_teams.map(&:name)

      ignored = IGNORE_REPOS.include? notification.repository.full_name
      involves_me = assignees.include?("mrysav") || requested_reviewers.include?("mrysav") || requested_teams.include?("dsp-dependency-graph-reviewers")

      if ignored && !involves_me
        client.mark_thread_as_read(notification.id)
        client.delete_thread_subscription(notification.id)
        puts "unsubscribed from: #{notification.subject.title}"
        next
      end

      if pr.state != "open"
        client.mark_thread_as_read(notification.id)
        client.delete_thread_subscription(notification.id)
        puts "unsubscribed from: #{notification.subject.title}"
      end
      
      if pr.draft
        client.mark_thread_as_read(notification.id)
        puts "marking #{notification.subject.title} as read"
      end
    end
  elsif notification.subject.type == "Issue"
    url = notification.subject.url
    if url && (match = url.match(ISSUES_REGEX))
      id = match.captures.first.to_i
      issue = client.issue(notification.repository.full_name, id)
      if issue.state != "open"
        client.mark_thread_as_read(notification.id)
        client.delete_thread_subscription(notification.id)
        puts "unsubscribed from: #{notification.subject.title}"
      end
    end
  elsif notification.subject.type == "Discussion"
    next
    # todo
  end
end
