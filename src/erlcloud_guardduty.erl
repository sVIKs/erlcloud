-module(erlcloud_guardduty).

-include_lib("erlcloud/include/erlcloud.hrl").
-include_lib("erlcloud/include/erlcloud_aws.hrl").

%%------------------------------------------------------------------------------
%% Library initialization.
%%------------------------------------------------------------------------------
-export([configure/2, configure/3, new/2, new/3]).

%%------------------------------------------------------------------------------
%% GuardDuty API Functions
%%------------------------------------------------------------------------------
-export([
    get_detector/1, get_detector/2,
    list_detectors/0, list_detectors/1, list_detectors/2, list_detectors/3
]).

-import(erlcloud_util, [filter_undef/1]).

-type gd_return() :: {ok, proplist()} | {error, term()}.

-spec new(AccessKeyID ::string(), SecretAccessKey :: string()) -> aws_config().
new(AccessKeyID, SecretAccessKey) ->
    #aws_config{access_key_id=AccessKeyID,
                secret_access_key=SecretAccessKey}.

-spec new(AccessKeyID :: string(), SecretAccessKey :: string(), Host :: string()) -> aws_config().
new(AccessKeyID, SecretAccessKey, Host) ->
    #aws_config{access_key_id=AccessKeyID,
                secret_access_key=SecretAccessKey,
                guardduty_host=Host}.

-spec configure(AccessKeyID :: string(), SecretAccessKey :: string()) -> ok.
configure(AccessKeyID, SecretAccessKey) ->
    put(aws_config, new(AccessKeyID, SecretAccessKey)),
    ok.

-spec configure(AccessKeyID :: string(), SecretAccessKey :: string(), Host :: string()) -> ok.
configure(AccessKeyID, SecretAccessKey, Host) ->
    put(aws_config, new(AccessKeyID, SecretAccessKey, Host)),
    ok.

%%------------------------------------------------------------------------------
%% API
%%------------------------------------------------------------------------------

%%------------------------------------------------------------------------------
%% @doc
%% GuardDuty API:
%% [https://docs.aws.amazon.com/guardduty/latest/ug/get-detector.html]
%%
%%------------------------------------------------------------------------------

-spec get_detector(DetectorId :: binary()) -> gd_return().
get_detector(DetectorId) ->
    get_detector(DetectorId, default_config()).

-spec get_detector(DetectorId :: binary(),
                   Config     :: aws_config()) -> gd_return().
get_detector(DetectorId, Config) ->
    Path = "/detector/" ++ binary_to_list(DetectorId),
    guardduty_request(Config, get, Path, undefined).


%%------------------------------------------------------------------------------
%% @doc
%% GuardDuty API:
%% [https://docs.aws.amazon.com/guardduty/latest/ug/list-detectors.html]
%%
%%------------------------------------------------------------------------------

-spec list_detectors() -> gd_return().
list_detectors() -> list_detectors(default_config()).

-spec list_detectors(Config :: aws_config()) -> gd_return().
list_detectors(Config) ->
    list_detectors(undefined, undefined, Config).

-spec list_detectors(Marker   :: binary(),
                     MaxItems :: integer()) -> gd_return().
list_detectors(Marker, MaxItems) ->
    list_detectors(Marker, MaxItems, default_config()).

-spec list_detectors(Marker   :: undefined | binary(),
                     MaxItems :: undefined | integer(),
                     Config   :: aws_config()) -> gd_return().
list_detectors(Marker, MaxItems, Config) ->
    Path = "/detector",
    QParams = filter_undef([{"Marker", Marker},
                            {"MaxItems", MaxItems}]),
    guardduty_request(Config, get, Path, undefined, QParams).


%%%------------------------------------------------------------------------------
%%% Internal Functions
%%%------------------------------------------------------------------------------

guardduty_request(Config, Method, Path, Body) ->
    guardduty_request(Config, Method, Path, Body, []).

guardduty_request(Config, Method, Path, Body, QParam) ->
    case erlcloud_aws:update_config(Config) of
        {ok, Config1} ->
            guardduty_request_no_update(Config1, Method, Path, Body, QParam);
        {error, Reason} ->
            {error, Reason}
    end.

guardduty_request_no_update(Config, Method, Path, Body, QParam) ->
    Form = case encode_body(Body) of
               <<>>   -> erlcloud_http:make_query_string(QParam);
               Value  -> Value
           end,
    Headers = headers(Method, Path, Config, encode_body(Body), QParam),
    case erlcloud_aws:aws_request_form_raw(
           Method, Config#aws_config.guardduty_scheme, Config#aws_config.guardduty_host,
           Config#aws_config.guardduty_port, Path, Form, Headers, [], Config) of
        {ok, Data} ->
            {ok, jsx:decode(Data, [])};
        E ->
            E
    end.

encode_body(undefined) ->
    <<>>.

headers(Method, Uri, Config, Body, QParam) ->
    Headers = [{"host", Config#aws_config.guardduty_host},
               {"content-type", "application/json"}],
    Region = erlcloud_aws:aws_region_from_host(Config#aws_config.guardduty_host),
    erlcloud_aws:sign_v4(Method, Uri, Config,
                         Headers, Body, Region, "guardduty", QParam).

default_config() -> erlcloud_aws:default_config().
