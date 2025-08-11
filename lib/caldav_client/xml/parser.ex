defmodule CalDAVClient.XML.Parser do
  @moduledoc """
  Parses XML responses received from the calendar server.
  """

  import SweetXml

  @event_xpath ~x"//*[local-name()='multistatus']/*[local-name()='response']"el
  @url_xpath ~x"./*[local-name()='href']/text()"s
  @icalendar_xpath ~x"./*[local-name()='propstat']/*[local-name()='prop']/*[local-name()='calendar-data']/text()"s
  @etag_xpath ~x"./*[local-name()='propstat']/*[local-name()='prop']/*[local-name()='getetag']/text()"s
  @status ~x"./*[local-name()='status']/text() | ./*[local-name()='propstat']/*[local-name()='status']/text()"s

  @doc """
  Parses XML response body into a list of events.
  """
  @spec parse_events(response_xml :: String.t()) :: [CalDAVClient.Event.t()]
  def parse_events(response_xml) do
    response_xml
    |> xpath(@event_xpath,
      url: @url_xpath,
      status: @status,
      icalendar: @icalendar_xpath,
      etag: @etag_xpath
    )
    |> Enum.map(&struct(CalDAVClient.Event, &1))
    |> Enum.map(fn event ->
      %{event | status: Regex.run(~r/\d{3}/, event.status) |> List.first()}
    end)
  end

  @spec parse_sync_response(response_xml :: String.t()) :: {String.t(), [CalDAVClient.Event.t()]}
  def parse_sync_response(response_xml) do
    sync_token = response_xml |> xpath(~x"//*[local-name()='sync-token']/text()"s)

    events =
      response_xml
      |> xpath(@event_xpath,
        url: @url_xpath,
        status: @status,
        icalendar: @icalendar_xpath,
        etag: @etag_xpath
      )
      |> Enum.map(&struct(CalDAVClient.Event, &1))
      |> Enum.map(fn event ->
        %{event | status: Regex.run(~r/\d{3}/, event.status) |> List.first()}
      end)

    %{sync_token: sync_token, events: events}
  end
end
