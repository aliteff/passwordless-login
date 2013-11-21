%%%-------------------------------------------------------------------
%%% @author abc
%%% @copyright (C) 2013, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 13. Nov 2013 11:36 PM
%%%-------------------------------------------------------------------
-module(target).
-behavior(gen_server).
-export([init/1, handle_info/2, handle_call/3, terminate/2, handle_cast/2,code_change/3]).
-include("records.erl").

-record(targetState, {targetID,privateCert,stsPublicKey}).

init({TargetID, Certificate, StsPublicKey}) ->
  {ok,#targetState{privateCert = Certificate, targetID = TargetID, stsPublicKey = StsPublicKey}}.

%% Request from the user to login into the target site.
%% Will normally be generated by the Web UI on the target site.
%% It will request confirmation from the trust server and act according to its reply.
handle_call({login,Username}, _From, State) ->
  io:format("Target: User ~p is loging in~n", [Username]),
  verify_target_user(State, Username),
  Msg = #target2sts{reason = "User login",
                    requestID = uuid:to_string(uuid:v4()),
                    targetID = State#targetState.targetID,
                    userName = Username},
  SignedMsg = auth_security:sign(Msg, State#targetState.privateCert),
  Reply = gen_server:call(trust_server, {verify, SignedMsg}),
  io:format("Target: Trust server reply: ~p~n", [Reply]),
  auth_security:verify_signature(Reply, State#targetState.stsPublicKey),
  case Reply of
    {confirmed, _} = Reply -> {reply, ok, State};
    _ -> {reply, false, State}
  end;

%% Request to store the targetID - happens only once during target's registration process.
handle_call({newTargetID, TargetID}, _From, State) ->
  NewState = State#targetState{targetID = TargetID},
  {reply,ok,NewState};

handle_call(terminate, _From, State) ->
  {stop, normal, ok, State};

handle_call(Msg, _From, State) ->
  io:format("Unexpected message: ~p~n",[Msg]),
  {reply, false, State}.

handle_info(Msg, State) ->
  io:format("Unexpected message: ~p~n",[Msg]),
  {noreply, State}.

handle_cast(stop, State) ->
  {stop, normal, State}.

terminate(normal, _State) ->
  io:format("Stopping the server~n"),
  ok.
code_change(_OldVsn, State, _Extra) ->
  {ok, State}.

%% ====================================== Private functions ======================================

% Verifies that the user is registered on the target system.
verify_target_user(_State, _Username) ->
  ok.
