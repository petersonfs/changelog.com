defmodule Changelog.Files.Cover do
  use Changelog.File, [:jpg, :png]

  alias Changelog.Podcast
  alias ChangelogWeb.PodcastView

  @versions [:original, :medium, :small]

  def storage_dir(_, _), do: "uploads/covers"

  def filename(version, {_, %{name: _} = scope}) do
    name = if Podcast.is_interviews(scope) do
      "changelog-interviews"
    else
      PodcastView.dasherized_name(scope)
    end

    "#{name}-#{version}"
  end

  def transform(:original, _), do: :noaction

  def transform(version, {_file, _scope}) do
    {:convert, convert_args("-resize #{dimensions(version)}")}
  end

  # defp dimensions(:original),  do: "3000x3000"
  defp dimensions(:medium), do: "440x440"
  defp dimensions(:small), do: "100x100"
end
