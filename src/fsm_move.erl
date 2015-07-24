%% Copyright (c) 2015, Oleksiy Kebkal <lesha@evologics.de>
%% 
%% Redistribution and use in source and binary forms, with or without 
%% modification, are permitted provided that the following conditions 
%% are met: 
%% 1. Redistributions of source code must retain the above copyright 
%%    notice, this list of conditions and the following disclaimer. 
%% 2. Redistributions in binary form must reproduce the above copyright 
%%    notice, this list of conditions and the following disclaimer in the 
%%    documentation and/or other materials provided with the distribution. 
%% 3. The name of the author may not be used to endorse or promote products 
%%    derived from this software without specific prior written permission. 
%% 
%% Alternatively, this software may be distributed under the terms of the 
%% GNU General Public License ("GPL") version 2 as published by the Free 
%% Software Foundation. 
%% 
%% THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR 
%% IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES 
%% OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. 
%% IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, 
%% INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT 
%% NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, 
%% DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY 
%% THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT 
%% (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF 
%% THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE. 
-module(fsm_move).
-behaviour(fsm).

-include("fsm.hrl").

-export([start_link/1, trans/0, final/0, init_event/0]).
-export([init/1,handle_event/3,stop/1]).

-export([handle_idle/3, handle_moving/3, handle_alarm/3]).

-import(geometry, [ecef2geodetic/1, ned2ecef/2]).

-define(TRANS, [
                {idle,
                 [{initial,idle},
                  {internal, moving}
                 ]},
                {moving,
                 [{tide, moving},
                  {brownian, moving},
                  {circle, moving},
                  {rocking, moving}
                 ]},
                {alarm,
                 []}]).

start_link(SM) -> fsm:start_link(SM).
init(SM)       ->
  P = [0,0,0], ets:insert(SM#sm.share, {tail, [P,P,P], 0.0,0.0,0.0}),
  ets:insert(SM#sm.share, {ahrs, [0,0,0]}),
  SM.
trans()        -> ?TRANS.
final()        -> [].
init_event()   -> initial.
stop(_SM)      -> ok.

handle_event(MM, SM, Term) ->
  case Term of
    {timeout, Event} ->
      fsm:run_event(MM, SM#sm{event=Event}, {});
    {connected} ->
      SM;
    _ ->
      SM
  end.

handle_idle(_MM, #sm{event = Event} = SM, _Term) ->
  case Event of
    initial -> 
      MS = [ets:lookup(SM#sm.share, T) || T <- [circle, brownian, tide, rocking]],
      ?TRACE(?ID, "MS: ~p~n", [MS]),
      lists:foreach(fun(M) ->
                        case M of
                          [{tide, {tide, Tau, _Pr, _Amp, _Phy, _Period}}] -> timer:send_interval(Tau, {timeout, tide});
                          [{circle, {circle, _C, _R, _V, Tau, _Phy}}] -> timer:send_interval(Tau, {timeout, circle});
                          [{brownian, {brownian,Tau,_,_,_,_,_,_,_,_,_}}] -> timer:send_interval(Tau, {timeout, brownian});
                          [{rocking, {rocking, Tau}}] -> timer:send_interval(Tau, {timeout, rocking});
                          _ ->
                            ?TRACE(?ID, "Hmmm: ~p~n", [M]),
                            nothing
                        end
                    end, lists:filter(fun(M) -> M /= [] end, MS)),
      fsm:set_event(SM, internal);
    _ ->
      fsm:set_event(SM#sm{state = alarm}, internal)
  end.

handle_moving(_MM, #sm{event = Event} = SM, _Term) ->
  case Event of
    internal ->
      fsm:set_event(SM, eps);
    tide ->
      %% Depth in meters
      [{tide, {tide, Tau, Depth, A, Phy, Period}}] = ets:lookup(SM#sm.share, tide),
      Phy1 = Phy + 2*math:pi()*Tau/Period,
      Depth1 = Depth + A * math:sin(Phy1),
      ets:insert(SM#sm.share, {tide, {tide, Tau, Depth, A, Phy1, Period}}),
      DBS = {dbs, Depth1},
      fsm:broadcast(SM, pressure, {send, {nmea, DBS}}),
      fsm:broadcast(fsm:set_event(SM, eps), nmea, {send, {nmea, DBS}});
    circle ->
      [{circle, {circle, C, R, V, Tau, Phy}}] = ets:lookup(SM#sm.share, circle),
      {XO, YO, ZO} = C,
      Phy1 = Phy + V*(Tau/1000)/R, 
      %% X,Y,Z in NED reference frame
      Xn = XO + R * math:cos(Phy1),
      Yn = YO + R * math:sin(Phy1),
      Zn = ZO,
      broadcast_position(SM, [Xn,Yn,Zn]),
      ets:insert(SM#sm.share, {circle, {circle, C, R, V, Tau, Phy1}}),
      fsm:set_event(SM, eps);
    brownian ->
      [{brownian, {brownian, Tau, XMin, YMin, ZMin, XMax, YMax, ZMax, X, Y, Z}}] = ets:lookup(SM#sm.share, brownian),
      Xn = geometry:brownian_walk(XMin, XMax, X),
      Yn = geometry:brownian_walk(YMin, YMax, Y),
      Zn = geometry:brownian_walk(ZMin, ZMax, Z),
      broadcast_position(SM, [Xn,Yn,Zn]),
      ets:insert(SM#sm.share, {brownian, {brownian, Tau, XMin, YMin, ZMin, XMax, YMax, ZMax, Xn, Yn, Zn}}),
      fsm:set_event(SM, eps);
    rocking ->
      [{ahrs, [Yaw, Pitch, Roll]}] = ets:lookup(SM#sm.share, ahrs),
      fsm:broadcast(fsm:set_event(SM, eps), nmea, {send, {nmea, {tnthpr,Yaw,"N",Pitch,"N",Roll,"N"}}});
    {nmea, _} ->
      SM;
    _ ->
      fsm:set_event(SM#sm{state = alarm}, internal)
  end.

broadcast_position(SM, [Xn,Yn,Zn]) ->
  [{lever_arm, Lever_arm}] = ets:lookup(SM#sm.share, lever_arm),
  [Psi, Theta, Phi] = rock(SM, [Xn,Yn,Zn]),
  %% converting to global reference system
  [Xl,Yl,Zl] = geometry:rotate({sensor, Lever_arm}, [Psi, Theta, Phi]),
  %% lever_arm to transducer is taken into account by transducer movement in the emulator
  [{_, Ref}] = ets:lookup(SM#sm.share, geodetic),
  [_,_,Alt] = ecef2geodetic(ned2ecef([0,0,Zn+Zl], Ref)),
  [{_,Sea_level}] = ets:lookup(SM#sm.share, sea_level),
  Str = lists:flatten(io_lib:format("~p ~p ~p", [Xn+Xl,Yn+Yl,Alt-Sea_level])),
  fsm:cast(SM, scli, {send, {string, Str}}),
  [Yaw, Pitch, Roll] = [V*180/math:pi() || V <- [Psi, Theta, Phi]],
  ets:insert(SM#sm.share, {ahrs, [Yaw,Pitch,Roll]}),
  broadcast_nmea(SM, apply_jitter(SM, [Xn, Yn, Zn])).

hypot(X,Y) ->
  math:sqrt(X*X + Y*Y).

sign(A) when A < 0 -> -1;
sign(_) -> 1.

%% turning left - roll positive, otherwise negative
%% values in radians
rock(SM, [E2,N2,_]=P2) ->
  K = 0.1,
  [{tail, [P1,P0,_], Pitch_phase, Heading_prev, Roll_prev}] = ets:lookup(SM#sm.share, tail),
  Pitch_phase1 = Pitch_phase + 2 * math:pi() / 20, %% freq dependend, here update each second
  Pitch = 5 * math:sin(Pitch_phase1) * math:pi() / 180,
  [E0,N0,_] = P0,
  [E1,N1,_] = P1,
  [W0,W1,W2] = [-E0,-E1,-E2],
  Heading = K * math:atan2(W2-W1,N2-N1) + (1-K) * Heading_prev,
  A = hypot(E1-E0,N1-N0),
  B = hypot(E2-E1,N2-N1),
  C = hypot(E2-E0,N2-N0),
  Alpha = try math:acos((C*C-A*A-B*B)/(2*A*B)) catch _:_ -> 0 end,
  AlphaA = math:atan2(W1-W0,N1-N0),
  AlphaB = Heading,
  Sign = sign(AlphaB - AlphaA),
  Roll = K * (Sign * Alpha / 10) + (1-K) * Roll_prev,
  ets:insert(SM#sm.share, {tail, [P2,P1,P0], Pitch_phase1, Heading, Roll}),
  [Heading, Pitch, Roll].

broadcast_nmea(SM, [X, Y, Z]) ->
  try  {MS,S,US} = os:timestamp(),
       {_,{HH,MM,SS}} = calendar:now_to_universal_time({MS,S,US}),
       Timestamp = 60*(60*HH + MM) + SS + US / 1000000,
       [{_, Ref}] = ets:lookup(SM#sm.share, geodetic),
       [Lat,Lon,Alt] = ecef2geodetic(ned2ecef([X,Y,Z], Ref)),

       GGA = {gga, Timestamp, Lat, Lon, 4,nothing,nothing,Alt,nothing,nothing,nothing},
       ZDA = {zda, Timestamp, 28, 11, 2013, 0, 0},
       fsm:broadcast(SM, nmea, {send, {nmea, GGA}}),
       fsm:broadcast(SM, nmea, {send, {nmea, ZDA}})
  catch T:E -> ?ERROR(?ID, "~p:~p~n", [T,E])
  end.

apply_jitter(SM, [X, Y, Z]) ->
  [{_, {jitter, Jx, Jy, Jz}}] = ets:lookup(SM#sm.share, jitter),
  [X + (2*Jx*random:uniform() - Jx),
   Y + (2*Jy*random:uniform() - Jy),
   Z + (2*Jz*random:uniform() - Jz)].

-spec handle_alarm(any(), any(), any()) -> no_return().
handle_alarm(_MM, SM, _Term) ->
  ?ERROR(?ID, "ALARM~n", []),
  exit({alarm, SM#sm.module}).
