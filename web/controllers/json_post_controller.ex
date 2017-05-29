defmodule Limpet.JsonPostController do
  use Limpet.Web, :controller
  require Logger

  alias Limpet.Post
  alias Limpet.Secrets

  def index(conn, _params) do
    json_posts = Repo.all(Post)
    |> Enum.map(fn(post) -> %{post | location: Geo.JSON.encode(post.location)} end)
    render(conn, "index.json", json_posts: json_posts)
  end

  def create(conn, %{"json_post" => json_post_params}) do

    params = handle_post_encryption(json_post_params)
    Logger.debug("Processed params: #{inspect(params)}")
    changeset = Post.changeset(%Post{}, params)

    case Repo.insert(changeset) do
      {:ok, json_post} ->
        conn
        |> put_status(:created)
        |> put_resp_header("location", json_post_path(conn, :show, json_post))
        |> render("show.json", json_post: json_post)
      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(Limpet.ChangesetView, "error.json", changeset: changeset)
    end
  end

  def show(conn, %{"id" => id}) do
    json_post = Repo.get!(Post, id)
    json_post = %{json_post | location: Geo.JSON.encode(json_post.location)}
    render(conn, "show.json", json_post: json_post)
  end

  def update(conn, %{"id" => id, "json_post" => json_post_params}) do
    %{json_post_params | location: Geo.JSON.decode(json_post_params.location)}
    json_post = Repo.get!(Post, id)
    changeset = Post.changeset(json_post, json_post_params)

    case Repo.update(changeset) do
      {:ok, json_post} ->
        render(conn, "show.json", json_post: json_post)
      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(Limpet.ChangesetView, "error.json", changeset: changeset)
    end
  end

  def delete(conn, %{"id" => id}) do
    json_post = Repo.get!(Post, id)

    # Here we use delete! (with a bang) because we expect
    # it to always work (and if it does not, it will raise).
    Repo.delete!(json_post)

    send_resp(conn, :no_content, "")
  end

  defp handle_post_encryption(params) do
    case params["is_encrypted"] do
      true ->
        Map.put(params, "message", Secrets.encrypt(params["message"], params["password"]))
      _ ->
        params
    end
  end

end
