defmodule ChangelogWeb.FeedController do
  use ChangelogWeb, :controller

  require Logger

  alias Changelog.{
    AgentKit,
    Episode,
    Metacast,
    NewsItem,
    NewsSource,
    Person,
    Podcast,
    Post,
    Topic
  }

  alias ChangelogWeb.Plug.ResponseCache

  plug :log_subscribers, "log podcast subscribers" when action in [:podcast]
  plug ResponseCache

  def news(conn, _params) do
    conn
    |> put_layout(false)
    |> put_resp_content_type("application/xml")
    |> assign(:items, NewsItem.latest_news_items())
    |> ResponseCache.cache_public(:timer.minutes(2))
    |> render("news.xml")
  end

  def news_titles(conn, _params) do
    conn
    |> put_layout(false)
    |> put_resp_content_type("application/xml")
    |> assign(:items, NewsItem.latest_news_items())
    |> ResponseCache.cache_public(:timer.minutes(2))
    |> render("news_titles.xml")
  end

  def podcast(conn, %{"slug" => "backstage"}) do
    send_resp(conn, :not_found, "")
  end

  def podcast(conn, %{"slug" => slug}) do
    feed = ChangelogWeb.Feeds.generate(slug)

    conn
    |> put_layout(false)
    |> put_resp_header("access-control-allow-origin", "*")
    |> put_resp_content_type("application/xml")
    |> send_resp(200, feed)
  end

  def plusplus(conn, %{"slug" => slug}) do
    if Application.get_env(:changelog, :plusplus_slug) == slug do
      feed = ChangelogWeb.Feeds.generate("plusplus")

      conn
      |> put_layout(false)
      |> put_resp_header("access-control-allow-origin", "*")
      |> put_resp_content_type("application/xml")
      |> send_resp(200, feed)
    else
      send_resp(conn, :not_found, "")
    end
  end

  def metacast(conn, %{"slug" => slug}) do
    metacast = Metacast.get_by_slug!(slug)

    if metacast.is_official do
      render_feed_for_metacast(conn, metacast)
    else
      send_resp(conn, :not_found, "")
    end
  end

  defp render_feed_for_metacast(conn, metacast, template \\ "podcast") do
    episodes =
      metacast
      |> Metacast.get_episode_ids!()
      |> Episode.with_ids()
      |> Episode.published()
      |> Episode.newest_first()
      |> Episode.exclude_transcript()
      |> Episode.preload_all()
      |> Repo.all()

    conn
    |> put_layout(false)
    |> put_resp_content_type("application/xml")
    |> assign(:podcast, metacast)
    |> assign(:episodes, episodes)
    |> ResponseCache.cache_public()
    |> render("#{template}.xml")
  end

  defp log_subscribers(conn = %{params: %{"slug" => slug}}, _) do
    ua = ChangelogWeb.Plug.Conn.get_agent(conn)

    case AgentKit.get_subscribers(ua) do
      {:ok, {agent, subs}} ->
        Logger.info("Known agent reporting: #{slug}, #{agent}, #{subs}")
        Podcast.update_subscribers(slug, agent, subs)

      {:error, :unknown_agent} ->
        Logger.info("Unknown agent reporting: #{ua}")

      {:error, _message} ->
        false
    end

    conn
  end

  def posts(conn, _params) do
    feed = ChangelogWeb.Feeds.generate("posts")

    conn
    |> put_layout(false)
    |> put_resp_content_type("application/xml")
    |> ResponseCache.cache_public(:timer.minutes(1))
    |> send_resp(200, feed)
  end

  def sitemap(conn, _params) do
    news_items =
      NewsItem.published()
      |> NewsItem.newest_first()
      |> Repo.all()

    news_sources =
      NewsSource
      |> Repo.all()

    episodes =
      Episode.published()
      |> Episode.newest_first()
      |> Episode.exclude_transcript()
      |> Episode.preload_podcast()
      |> Repo.all()

    people =
      Person.with_public_profile()
      |> Repo.all()

    podcasts =
      Podcast.public()
      |> Podcast.oldest_first()
      |> Repo.all()
      |> Kernel.++([Podcast.master()])

    posts =
      Post.published()
      |> Post.newest_first()
      |> Repo.all()

    topics =
      Topic.with_news_items()
      |> Repo.all()

    conn
    |> put_layout(false)
    |> assign(:news_items, news_items)
    |> assign(:news_sources, news_sources)
    |> assign(:episodes, episodes)
    |> assign(:people, people)
    |> assign(:podcasts, podcasts)
    |> assign(:posts, posts)
    |> assign(:topics, topics)
    |> ResponseCache.cache_public(:timer.minutes(5))
    |> render("sitemap.xml")
  end
end
