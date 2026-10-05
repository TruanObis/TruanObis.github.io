require "bundler/setup"
require "minitest/autorun"
require "jekyll"
require "tmpdir"
require "fileutils"
require "json"
require "rexml/document"
require "open3"

class SiteTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)
  UID = "59ac2a53-cadc-4dca-8a31-3e1a1e6dcfcf"
  POST = "_posts/2026-01-01-#{UID}.md"

  def setup
    @tmp = Dir.mktmpdir("blog-test-")
    @source = File.join(@tmp, "source")
    @dest = File.join(@tmp, "public")
    FileUtils.mkdir_p(@source)
    Dir.children(ROOT).reject { |n| %w[.git .bundle vendor _site .jekyll-cache test].include?(n) }.each do |name|
      FileUtils.cp_r(File.join(ROOT, name), @source)
    end
    FileUtils.mkdir_p(File.join(@source, "_posts"))
    write_post
  end

  def teardown
    FileUtils.remove_entry(@tmp)
  end

  def write_post(title: '한글 "제목" <글>', body: "실제 본문입니다.\n\n## 소제목\n\n![그림](/assets/uploads/example.svg)\n\n`{{ untouched }}`\n", published: true, uid: UID, path: POST, date: "2026-01-01")
    front = { "title" => title, "date" => date, "uid" => uid, "published" => published, "description" => '따옴표 "와" & 한글', "tags" => ["기록", "한글"] }
    File.write(File.join(@source, path), front.to_yaml + "---\n" + body, encoding: "UTF-8")
  end

  def build
    FileUtils.rm_rf(@dest)
    config = Jekyll.configuration("source" => @source, "destination" => @dest, "quiet" => true, "url" => "https://example.test", "baseurl" => "", "future" => false)
    Jekyll::Site.new(config).process
  end

  def read(path)
    file = File.join(@dest, path)
    assert File.file?(file), "Expected generated file #{path}"
    File.read(file, encoding: "UTF-8")
  end

  def posts
    JSON.parse(read("posts.json"))
  end

  def test_complete_body_and_raw_markdown_are_readable_without_javascript
    build
    html = read("posts/#{UID}/index.html")
    assert_includes html, "실제 본문입니다."
    assert_includes html, "한글 &quot;제목&quot; &lt;글&gt;"
    assert_includes html, "text/markdown"
    assert_includes html, "/assets/uploads/example.svg"
    raw = read("posts/#{UID}/index.md")
    assert_includes raw, "## 소제목"
    assert_includes raw, "`{{ untouched }}`"
    refute_includes raw, "<h2"
    assert_equal '한글 "제목" <글>', posts.first.fetch("title")
    REXML::Document.new(read("feed.xml"))
    REXML::Document.new(read("sitemap.xml"))
    schema = html.scan(%r{<script type="application/ld\+json">(.*?)</script>}m).flatten.map { |s| JSON.parse(s) }
    assert schema.any? { |s| s["@type"] == "BlogPosting" }
  end

  def test_title_and_content_edit_preserve_url_and_update_exports
    build
    before = posts.first.fetch("url")
    write_post(title: "바뀐 제목", body: "바뀐 본문\n")
    build
    assert_equal before, posts.first.fetch("url")
    assert_equal "https://example.test/posts/#{UID}/", before
    assert_includes read("posts/#{UID}/index.md"), "바뀐 본문"
    refute_includes read("posts/#{UID}/index.md"), "실제 본문"
    assert_includes read("llms.txt"), "바뀐 제목"
  end

  def test_unpublished_future_and_deleted_posts_have_no_public_exports
    write_post(title: "숨김 글", published: false, uid: "9d626592-c907-4601-9fda-e18cd6ca9cbf", path: "_posts/2026-01-02-hidden.md")
    write_post(title: "미래 글", date: "2099-01-01", uid: "63157d94-d8bf-4f39-9874-034b0d3f20d6", path: "_posts/2099-01-01-future.md")
    build
    assert_equal 1, posts.length
    %w[index.html llms.txt feed.xml sitemap.xml posts.json].each do |path|
      refute_includes read(path), "숨김 글"
      refute_includes read(path), "미래 글"
    end
    assert_equal 1, Dir.glob(File.join(@dest, "posts/*/index.md")).length
    File.delete(File.join(@source, POST))
    build
    assert_empty posts
    refute File.exist?(File.join(@dest, "posts", UID))
    refute_includes read("llms.txt"), UID
    assert_includes read("index.html"), "아직 공개된 글이 없습니다"
  end

  def test_blank_identity_is_not_replaced_by_account_name
    build
    html = read("posts/#{UID}/index.html")
    refute_match(/<[^>]*class="[^"]*author/, html)
    schema = JSON.parse(html.match(%r{<script type="application/ld\+json">(.*?)</script>}m)[1])
    refute schema.key?("author")
    refute_includes read("index.html"), "TruanObis의 기록"
  end

  def test_modified_time_comes_from_the_content_commit
    system("git", "init", "--quiet", @source, out: File::NULL)
    system("git", "-C", @source, "add", POST, out: File::NULL)
    env = { "GIT_AUTHOR_DATE" => "2026-02-03T04:05:06+09:00", "GIT_COMMITTER_DATE" => "2026-02-03T04:05:06+09:00" }
    ok = system(env, "git", "-C", @source, "-c", "user.name=Test", "-c", "user.email=test@example.invalid", "commit", "--quiet", "-m", "Fixture post", out: File::NULL)
    assert ok
    build
    assert_equal "2026-02-03T04:05:06+09:00", posts.first.fetch("modified")
    assert_includes read("sitemap.xml"), "2026-02-03T04:05:06+09:00"
  end

  def test_duplicate_ids_fail_build_instead_of_overwriting_a_post
    write_post(title: "중복 글", path: "_posts/2026-01-03-duplicate.md")
    error = assert_raises(Jekyll::Errors::FatalException) { build }
    assert_match(/duplicate.*uid/i, error.message)
  end
end
