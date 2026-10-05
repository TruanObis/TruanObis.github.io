require "cgi"
require "json"
require "open3"
require "pathname"
require "time"

module BlogExports
  # Static output avoids converting Markdown to HTML or evaluating its Liquid.
  class TextFile < Jekyll::StaticFile
    def initialize(site, path, text)
      super(site, site.source, File.dirname(path), File.basename(path))
      @text = text
    end

    def write(dest)
      target = destination(dest)
      FileUtils.mkdir_p(File.dirname(target))
      File.write(target, @text, encoding: "UTF-8")
      true
    end

    def modified?
      true
    end
  end

  class Generator < Jekyll::Generator
    priority :highest
    UID_PATTERN = /\A[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/i

    def generate(site)
      @site = site
      @identity = site.data.fetch("site", {})
      @author = @identity.fetch("author", "").to_s.strip
      @title = @identity.fetch("title", "").to_s.strip
      seen = {}
      entries = site.posts.docs.sort_by(&:date).reverse.map do |post|
        uid = post.data["uid"].to_s.downcase
        unless UID_PATTERN.match?(uid)
          raise Jekyll::Errors::FatalException, "Missing or invalid uid in #{post.relative_path}; create posts through Pages CMS or add a UUID v4."
        end
        raise Jekyll::Errors::FatalException, "Duplicate uid #{uid} in #{post.relative_path}" if seen[uid]
        seen[uid] = true
        post.data["permalink"] = "/posts/#{uid}/"
        post.data["last_modified_at"] = modified_at(post)
        post.data["markdown_url"] = "/posts/#{uid}/index.md"
        entry = {
          "id" => uid,
          "title" => post.data["title"].to_s,
          "url" => absolute(post.data["permalink"]),
          "markdown_url" => absolute(post.data["markdown_url"]),
          "published" => post.date.iso8601,
          "modified" => post.data["last_modified_at"],
          "description" => post.data.fetch("description", "").to_s,
          "tags" => Array(post.data["tags"]),
          "policy_url" => absolute("/policy/")
        }
        entry["author"] = @author unless @author.empty?
        schema = {
          "@context" => "https://schema.org", "@type" => "BlogPosting",
          "headline" => entry["title"], "url" => entry["url"],
          "datePublished" => entry["published"], "dateModified" => entry["modified"],
          "inLanguage" => "ko", "mainEntityOfPage" => entry["url"],
          "description" => entry["description"], "license" => entry["policy_url"]
        }
        schema["author"] = { "@type" => "Person", "name" => @author } unless @author.empty?
        post.data["schema_json"] = JSON.generate(schema).gsub("<", '\\u003c')
        header = ["# #{entry['title']}", "", "URL: #{entry['url']}", "Published: #{entry['published']}", "Modified: #{entry['modified']}"]
        header << "Author: #{@author}" unless @author.empty?
        header += ["Usage: #{entry['policy_url']}", "", post.content]
        add("posts/#{uid}/index.md", header.join("\n") + "\n")
        entry.merge("body" => post.content)
      end
      add("posts.json", JSON.pretty_generate(entries.map { |e| e.reject { |k, _| k == "body" } }) + "\n")
      add("llms.txt", llms(entries))
      add("sitemap.xml", sitemap(entries))
      add("feed.xml", feed(entries))
    end

    private

    def add(path, text)
      @site.static_files << TextFile.new(@site, path, text)
    end

    def absolute(path)
      @site.config.fetch("url").sub(%r{/$}, "") + @site.config.fetch("baseurl", "").sub(%r{/$}, "") + path
    end

    def modified_at(post)
      path = Pathname.new(post.path).relative_path_from(Pathname.new(@site.source)).to_s
      value, status = Open3.capture2("git", "-C", @site.source, "log", "-1", "--format=%cI", "--", path, err: File::NULL)
      return Time.iso8601(value.strip).iso8601 if status.success? && !value.strip.empty?
      post.date.iso8601
    rescue Errno::ENOENT, ArgumentError
      post.date.iso8601
    end

    def xml(value)
      CGI.escapeHTML(value.to_s)
    end

    def llms(entries)
      title = @title.empty? ? "글 목록" : @title
      lines = ["# #{title}", "", "> 한국어 공개 글과 Markdown 원문입니다. 작성자 소유 콘텐츠의 AI 검색·학습을 허용합니다.", "", "## 이용 안내", "", "- [이용 조건](#{absolute('/policy/')})", "- [JSON 글 목록](#{absolute('/posts.json')})", "- [RSS 피드](#{absolute('/feed.xml')})", "", "## 글", ""]
      entries.each do |entry|
        label = entry["title"].gsub(/[\r\n]/, " ").gsub(/[\[\]\\]/) { |char| "\\#{char}" }
        lines << "- [#{label}](#{entry['markdown_url']}): #{entry['description'].gsub(/[\r\n]/, ' ')}"
      end
      lines << "아직 공개된 글이 없습니다." if entries.empty?
      lines.join("\n") + "\n"
    end

    def sitemap(entries)
      urls = ["/", "/policy/"].map { |p| "<url><loc>#{xml(absolute(p))}</loc></url>" }
      urls += entries.map { |e| "<url><loc>#{xml(e['url'])}</loc><lastmod>#{xml(e['modified'])}</lastmod></url>" }
      %(<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n#{urls.join("\n")}\n</urlset>\n)
    end

    def feed(entries)
      # RSS allows omitting authors entirely when the configured byline is blank.
      title = @title.empty? ? "글 목록" : @title
      items = entries.map do |e|
        "<item><guid isPermaLink=\"true\">#{xml(e['url'])}</guid><title>#{xml(e['title'])}</title><link>#{xml(e['url'])}</link><pubDate>#{Time.iso8601(e['published']).rfc2822}</pubDate><description>#{xml(e['description'])}</description></item>"
      end
      %(<?xml version="1.0" encoding="UTF-8"?>\n<rss version="2.0" xmlns:atom="http://www.w3.org/2005/Atom"><channel><title>#{xml(title)}</title><link>#{xml(absolute('/'))}</link><description>공개 글 목록</description><language>ko</language><atom:link href="#{xml(absolute('/feed.xml'))}" rel="self" type="application/rss+xml"/>#{items.join("\n")}</channel></rss>\n)
    end
  end
end
