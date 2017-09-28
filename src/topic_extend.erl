%%%-------------------------------------------------------------------
%%% @author zhang
%%% @copyright (C) 2017, mixlinker.com
%%% @doc
%%%
%%% @end
%%% Created : 04. 八月 2017 15:15
%%%-------------------------------------------------------------------
-module(topic_extend).
-author("zhang").
-include_lib("emqttd/include/emqttd.hrl").
%% API
-export([start_init/0, add_client_group/2, match_this/4]).
-define(GROUP_TAB, client_group).
start_init() ->
    ets:new(?GROUP_TAB, [set, named_table, public, {read_concurrency, true}]),
%%    json test
    X1 = jsx:encode([{<<"a">>, 1}, {<<"b">>, <<"this is a test json">>}]),
    Jbin = <<"[\"abx\", \"bcx\", \"hh\"]">>,
    case jsx:is_json(Jbin) of
        true ->
            X2 = jsx:decode(Jbin);
        false ->
            X2 = "is not a json"
    end,
    lager:info("X1 jsx:encode = ~p ~n", [X1]),
    lager:info("X2 jsx:decode = ~p ~n", [X2]).

add_client_group(Client, Rsp_body) ->
    lager:debug("response body = ~p", [Rsp_body]),
    Rsp_bin = list_to_binary(Rsp_body),
%%    lager:debug("list_to_binary body = ~p", [Rsp_bin]),
    case Rsp_bin of
        <<"">> ->
            Groups = [];
        <<"[]">> ->
            Groups = [];
        _ ->
            Groups = binary:split(Rsp_bin, [<<",">>], [global]),
            ets:insert(?GROUP_TAB, {Client#mqtt_client.client_id, Groups})
    end,
    lager:info("Groups = ~p", [Groups]).
%%    Groups = [<<"abc">>, <<"bcd">>]
%%    ets:insert(client_group, {Client#mqtt_client.client_id, Groups}).



match(_Client, _Topic, []) ->
    nomatch;

match(Client, Topic, [Rule | Rules]) ->
    case emqttd_access_rule:match(Client, Topic, Rule) of
        nomatch -> match(Client, Topic, Rules);
        {matched, AllowDeny} -> {matched, AllowDeny}
    end.


match_this(Client, Topic, PubSub, Body) ->
    Rule = case binary:split(iolist_to_binary(Body), [<<",">>], [global]) of
               [] ->
                   {allow, all};
               [<<"">>] ->
                   {allow, all};
               [<<$#>>] ->
                   {allow, all};
               Topics ->
                   lager:debug("PubSub=~p Topics=~p",[PubSub, Topics]),
                   {allow, all, PubSub, Topics};
               _ ->
                   {deny, all}
           end,
    case match(Client, Topic, [emqttd_access_rule:compile(Rule)]) of
        {matched, allow} -> allow;
        {matched, deny} -> deny;
        nomatch -> deny
    end.