defmodule CalDAVClient.Calendar do
  @moduledoc """
  Allows for managing calendars on the calendar server.
  """

  import CalDAVClient.HTTP.Error
  import CalDAVClient.Tesla

  @xml_middlewares [
    CalDAVClient.Tesla.ContentTypeXMLMiddleware,
    CalDAVClient.Tesla.ContentLengthMiddleware
  ]

  @doc """
  Creates a calendar (see [RFC 4791, section 5.3.1.2](https://tools.ietf.org/html/rfc4791#section-5.3.1.2)).

  ## Options
  * `name` - calendar name.
  * `description` - calendar description.
  """
  @spec create(CalDAVClient.Client.t(), calendar_url :: String.t(), opts :: keyword()) ::
          :ok | {:error, any()}
  def create(caldav_client, calendar_url, opts \\ []) do
    case caldav_client
         |> make_tesla_client(@xml_middlewares)
         |> Tesla.request(
           method: :mkcalendar,
           url: calendar_url,
           body: CalDAVClient.XML.Builder.build_create_calendar_xml(opts)
         ) do
      {:ok, %Tesla.Env{status: code}} ->
        case code do
          201 -> :ok
          405 -> {:error, :already_exists}
          _ -> {:error, reason_atom(code)}
        end

      {:error, _reason} = error ->
        error
    end
  end

  @doc """
  Updates a specific calendar.

  ## Options
  * `name` - calendar name.
  * `description` - calendar description.
  """
  @spec update(CalDAVClient.Client.t(), calendar_url :: String.t(), opts :: keyword()) ::
          :ok | {:error, any()}
  def update(caldav_client, calendar_url, opts \\ []) do
    case caldav_client
         |> make_tesla_client(@xml_middlewares)
         |> Tesla.request(
           method: :proppatch,
           url: calendar_url,
           body: CalDAVClient.XML.Builder.build_update_calendar_xml(opts)
         ) do
      {:ok, %Tesla.Env{status: code}} ->
        case code do
          207 -> :ok
          _ -> {:error, reason_atom(code)}
        end

      {:error, _reason} = error ->
        error
    end
  end

  @doc """
  Deletes a specific calendar.
  """
  @spec delete(CalDAVClient.Client.t(), calendar_url :: String.t()) :: :ok | {:error, any()}
  def delete(caldav_client, calendar_url) do
    case caldav_client
         |> make_tesla_client()
         |> Tesla.delete(calendar_url) do
      {:ok, %Tesla.Env{status: code}} ->
        case code do
          204 -> :ok
          _ -> {:error, reason_atom(code)}
        end

      {:error, _reason} = error ->
        error
    end
  end

  @spec get_calendar_properties(CalDAVClient.Client.t(), String.t()) :: {:ok, map} | {:error, any}
  def get_calendar_properties(caldav_client, calendar_url) do
    case caldav_client
         |> make_tesla_client(@xml_middlewares)
         |> Tesla.request(
           method: :propfind,
           url: calendar_url,
           headers: [{"Depth", "0"}],
           body: CalDAVClient.XML.Builder.build_retrieve_calendar_properties()
         ) do
      {:ok, %Tesla.Env{status: code, body: xml_body}} ->
        case code do
          207 ->
            {:ok, parse_propfind_response(xml_body)}

          _ ->
            {:error, reason_atom(code)}
        end

      {:error, _reason} = error ->
        error
    end
  end

  @spec get_calendar_report(CalDAVClient.Client.t(), String.t(), String.t()) ::
          {:ok, map} | {:error, any}
  def get_calendar_report(caldav_client, calendar_url, sync_token) do
    # bad request with a value of 1
    depth = 1
    limit = 10

    case caldav_client
         |> make_tesla_client(@xml_middlewares)
         |> Tesla.request(
           method: :report,
           url: calendar_url,
           headers: [{"Depth", Integer.to_string(depth)}],
           body: CalDAVClient.XML.Builder.build_report_calendar(sync_token, depth, limit)
         ) do
      {:ok, %Tesla.Env{status: code, body: xml_body}} ->
        case code do
          207 ->
            {:ok, CalDAVClient.XML.Parser.parse_sync_response(xml_body)}

          _ ->
            {:error, reason_atom(code)}
        end

      {:error, _reason} = error ->
        error
    end
  end

  defp parse_propfind_response(xml_body) do
    [_, ctag] = Regex.run(~r/<cs:getctag>(\d+)<\/cs:getctag>/, xml_body)
    [_, display_name] = Regex.run(~r/D:displayname>(.+)<\/D:displayname>/, xml_body)
    [_, sync_token] = Regex.run(~r/D:sync-token>(.+)<\/D:sync-token>/, xml_body)

    %{
      ctag: ctag,
      display_name: display_name,
      sync_token: sync_token
    }
  end
end
