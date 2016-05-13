%% Copyright (c) 2015, Veronika Kebkal <veronika.kebkal@evologics.de>
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

%SRC has to be the first in the list
-define(NTP, true).
-define(SRC, 1).
-define(INTERVALS, [15]).
-define(NODES, [1, 2, 3, 4, 5, 6, 7]).
-define(SOUND_SPEED, 1408.5).
-define(SIGNAL_LENGTH, 0.387).

% -define(POSITION(T),
%     case T of
%         1 -> {46.8297222, 143.1388889};
%         2 -> {46.8333056, 143.1431111};
%         3 -> {46.8222222, 143.1166667};
%         4 -> {46.8194444, 143.1250000};
%         5 -> {46.8319444, 143.1333333};
%         6 -> {46.8183333, 143.1311111};
%         7 -> {46.8226389, 143.1418333};
%         9 -> {46.8277778, 143.1166667}
%     end).


%sensor pos
-define(POSITION(T),
    case T of
        1 -> {46.8277778, 143.1166667};
        2 -> {46.8333056, 143.1431111};
        3 -> {46.8222222, 143.1166667};
        4 -> {46.8194444, 143.1250000};
        5 -> {46.8297222, 143.1388889};
        7 -> {46.8226389, 143.1418333}
    end).

% TODO!!!!

-define(TYPEMSGMAX, 3).
-define(TYPESENSORMAX, 5).

-define(LIST_ALL_SENSORS, [no_sensor,
           pressure,
           conductivity,
           oxygen]).

-define(SENTYPEMSG2NUM(N),
  case N of
      error  -> 0;
      get_data  -> 1;
      recv_data  -> 2
  end).

-define(SENTYPESENSOR2NUM(N),
  case N of
      no_sensor  -> 0;
      pressure   -> 1;
      conductivity -> 2;
      oxygen -> 3
  end).

-define(SENNUM2TYPEMSG(N),
  case N of
      0 -> error;
      1 -> get_data;
      2 -> recv_data
  end).

-define(SENNUM2TYPESENSOR(N),
  case N of
      0 -> no_sensor;
      1 -> pressure;
      2 -> conductivity;
      3 -> oxygen
  end).