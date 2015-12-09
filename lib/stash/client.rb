require 'stash/client/version'
require 'faraday'
require 'addressable/uri'
require 'json'

module Stash
  class Client
    attr_reader :url

    public

    def initialize(opts = {})
      opts[:client] ? @client = opts[:client] : parse_opts(opts)
    end

    def projects
      fetch_all(@url.join('projects'))
    end

    def create_project(opts={})
      post(@url.join('projects'), opts)
    end

    def update_project(project, opts={})
      relative_project_path = project.fetch('link').fetch('url')
      put(@url.join(remove_leading_slash(relative_project_path)), opts)
    end

    def delete_project(project)
      relative_project_path = project.fetch('link').fetch('url')
      delete(@url.join(remove_leading_slash(relative_project_path)))
    end

    def repositories
      projects.map do |project|
        relative_project_path = project.fetch('link').fetch('url') + '/repos'
        fetch_all(@url.join(remove_leading_slash(relative_project_path)))
      end.flatten
    end

    def repositories_for_project(project)
      repos = []

      begin
        project.to_i == 0 ? key = 'name' : key = 'id'
        repositories.each { |e| repos.push(e) if e['project'][key] == project }
      rescue Exception => e
        raise_error(ArgumentError, e, "The input must be either the repository's name or ID")
      end

      return repos
    end

    def project_named(name)
      projects.find { |e| e['name'].eql?(name) }
    end

    def project_with_key(key)
      projects.find { |e| e['project']['key'].eql?(key) }
    end

    def repository_named(name)
      repositories.find { |e| e['name'].eql?(name) }
    end

    def repository_with_id(id)
      repositories.find { |e| e['id'] == id.to_i }
    end

    def clone_url_for(repo, format = 'ssh')
      the_url = nil

      unless format.eql?('https') || format.eql?('ssh')
        raise_error(ArgumentError, '', "The clone url format must be either 'https' or 'ssh'")
      end

      begin
        repo.to_i == 0 ? the_repo = repository_named(repo) : the_repo = repository_with_id(repo)
        the_repo['links']['clone'].each { |e| the_url = e['href'] if i['name'].eql?(format) }
      rescue Exception => e
        raise_error(ArgumentError, e, "The input must be either the repository's name or ID")
      end

      return the_url
    end

    def commits_for(repo, opts = {})
      query_values = {}

      path = remove_leading_slash(repo.fetch('link').fetch('url').sub('browse', 'commits'))
      uri = @url.join(path)

      query_values['since'] = opts[:since] if opts[:since]
      query_values['until'] = opts[:until] if opts[:until]
      query_values['limit'] = Integer(opts[:limit]) if opts[:limit]

      # default limit to 100 commits
      query_values['limit'] = 100 if query_values.empty?

      uri.query_values = query_values

      query_values['limit'] && query_values['limit'] < 100 ? fetch(uri).fetch('values') : fetch_all(uri)
    end

    def compare_commits_for(repo, opts = {})
      query_values = {}

      path = remove_leading_slash(repo.fetch('link').fetch('url').sub('browse', 'compare/commits'))
      uri = @url.join(path)

      query_values['from'] = opts[:from] if opts[:from]
      query_values['to'] = opts[:to] if opts[:to]
      query_values['limit'] = Integer(opts[:limit]) if opts[:limit]

      # default limit to 100 commits
      query_values['limit'] = 100 if query_values.empty?

      uri.query_values = query_values

      query_values['limit'] && query_values['limit'] < 100 ? fetch(uri).fetch('values') : fetch_all(uri)
    end

    def changes_for(repo, sha, opts = {})
      path = remove_leading_slash(repo.fetch('link').fetch('url').sub('browse', 'changes'))
      uri = @url.join(path)

      query_values = { 'until' =>  sha }
      query_values['since'] = opts[:parent] if opts[:parent]
      query_values['limit'] = opts[:limit] if opts[:limit]

      uri.query_values = query_values

      query_values['limit'] ? fetch(uri).fetch('values') : fetch_all(uri)
    end

    def branches_for(repo, opts = {})
      query_values = {}

      path = remove_leading_slash(repo.fetch('link').fetch('url').sub('browse', 'branches'))
      uri = @url.join(path)

      query_values['base'] = opts[:base] if opts[:base]
      query_values['details'] = opts[:details] if opts[:details]
      query_values['filterText'] = opts[:filterText] if opts[:filterText]
      query_values['orderBy'] = opts[:orderBy] if opts[:orderBy]
      query_values['limit'] = Integer(opts[:limit]) if opts[:limit]

      # default limit to 100 commits
      query_values['limit'] = 100 if query_values.empty?

      uri.query_values = query_values

      query_values['limit'] && query_values['limit'] < 100 ? fetch(uri).fetch('values') : fetch_all(uri)
    end

    def branch_tags_for(repo, opts = {})
      query_values = {}

      path = remove_leading_slash(repo.fetch('link').fetch('url').sub('browse', 'tags'))
      uri = @url.join(path)

      query_values['filterText'] = opts[:filterText] if opts[:filterText]
      query_values['limit'] = Integer(opts[:limit]) if opts[:limit]

      # default limit to 100 commits
      query_values['limit'] = 100 if query_values.empty?

      uri.query_values = query_values

      query_values['limit'] && query_values['limit'] < 100 ? fetch(uri).fetch('values') : fetch_all(uri)
    end

    private

    def parse_opts(opts)
      if opts[:host] && opts[:scheme]
        @url = Addressable::URI.parse("#{opts[:scheme]}://#{opts[:host]}/rest/api/1.0/")
      elsif opts[:host]
        @url = Addressable::URI.parse("http://#{opts[:host]}/rest/api/1.0/")
      elsif opts[:url]
        @url = Addressable::URI.parse(opts[:url])
      elsif opts[:uri] && opts[:uri].kind_of?(Addressable::URI)
        @url = opts[:uri]
      else
        raise_error(ArgumentError, '', 'must provide :url or :host')
      end

      @url.userinfo = opts[:credentials] if opts[:credentials]
      @client = Faraday.new(@url.site)
    end

    def raise_error(error_type, error_message = '', custom_message = '')
      message = ''
      message = "ERROR: #{error_message}\n#{custom_message}" unless error_message.eql('') && custom_message.eql?('')
      raise(error_type, message)
    end

    def fetch_all(uri)
      response, result = {}, []

      until response['isLastPage']
        response = fetch(uri)

        return nil unless response['values']
        result += response['values']

        next_page_start = response['nextPageStart'] || (response['start'] + response['size'])
        uri.query_values = (uri.query_values || {}).merge('start' => next_page_start)
      end

      result
    end

    def fetch(uri)
      res = @client.get do |req|
        req.url(uri.to_s)
        req.headers['Accept'] = 'application/json'
      end

      parse(res.body)
    end

    def post(uri, data)
      res = @client.post do |req|
        req.url(uri.to_s)
        req.body = data.to_json

        req.headers['Content-Type'] = 'application/json'
        req.headers['Accpet'] = 'application/json'
      end

      parse(res.body)
    end

    def put(uri, data)
      res = @client.put do |req|
        req.url(uri.to_s)
        req.body = data.to_json

        req.headers['Content-Type'] = 'application/json'
        req.headers['Accpet'] = 'application/json'
      end

      parse(res.body)
    end

    def delete(uri)
      res = @client.delete do |req|
        req.url(uri.to_s)
        req.headers['Accpet'] = 'application/json'
      end

      res.body
    end

    def parse(str)
      begin
        JSON.parse(str)
      rescue Encoding::InvalidByteSequenceError
        # HACK
        JSON.parse(str.force_encoding('UTF-8'))
      end
    end

    def remove_leading_slash(str)
      str.sub(/\A\//, '')
    end
  end
end
