%%
%% %CopyrightBegin%
%% 
%% Copyright Ericsson AB 2008-2010. All Rights Reserved.
%% 
%% The contents of this file are subject to the Erlang Public License,
%% Version 1.1, (the "License"); you may not use this file except in
%% compliance with the License. You should have received a copy of the
%% Erlang Public License along with this software. If not, it can be
%% retrieved online at http://www.erlang.org/.
%% 
%% Software distributed under the License is distributed on an "AS IS"
%% basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See
%% the License for the specific language governing rights and limitations
%% under the License.
%% 
%% %CopyrightEnd%
%%%-------------------------------------------------------------------
%%% File    : wx_event_SUITE.erl
%%% Author  : Dan Gudmundsson <dan.gudmundsson@ericsson.com>
%%% Description : Test event handling as much as possible
%%% Created :  3 Nov 2008 by Dan Gudmundsson <dan.gudmundsson@ericsson.com>
%%%-------------------------------------------------------------------
-module(wx_event_SUITE).
-export([all/0, suite/0,groups/0,init_per_group/2,end_per_group/2, 
	 init_per_suite/1, end_per_suite/1, 
	 init_per_testcase/2, end_per_testcase/2]).

-compile(export_all).

-include("wx_test_lib.hrl").

%% Initialization functions.
init_per_suite(Config) ->
    wx_test_lib:init_per_suite(Config).

end_per_suite(Config) ->
    wx_test_lib:end_per_suite(Config).

init_per_testcase(Func,Config) ->
    wx_test_lib:init_per_testcase(Func,Config).
end_per_testcase(Func,Config) -> 
    wx_test_lib:end_per_testcase(Func,Config).

%% SUITE specification
suite() -> [{ct_hooks,[ts_install_cth]}].

all() -> 
    [connect, disconnect, connect_msg_20, connect_cb_20,
     mouse_on_grid, spin_event, connect_in_callback].

groups() -> 
    [].

init_per_group(_GroupName, Config) ->
    Config.

end_per_group(_GroupName, Config) ->
    Config.

  
%% The test cases

%% Test that the various options to connect work as expected.
connect(TestInfo) when is_atom(TestInfo) -> wx_test_lib:tc_info(TestInfo);
connect(Config) ->
    ?mr(wx_ref, wx:new()),
    Frame = ?mt(wxFrame, wxFrame:new(wx:null(), 1, "Event Testing")),
    Panel = ?mt(wxPanel, wxPanel:new(Frame)),
    Window = wxWindow:new(Panel, -1),

    Tester = self(),
    CB = fun(#wx{event=#wxSize{},userData=UserD}, SizeEvent) ->
		 ?mt(wxSizeEvent, SizeEvent),
		 Tester ! {got_size, UserD}
	 end,
    
    ?m(ok, wxFrame:connect(Frame,  size)),
    ?m(ok, wxEvtHandler:connect(Panel, size,[{skip, true},{userData, panel}])),
    ?m(ok, wxEvtHandler:connect(Panel, size,[{callback,CB},{userData, panel}])),

    ?m({'EXIT', {{badarg,_},_}}, 
       wxEvtHandler:connect(Panel, there_is_no_such_event)),

    ?m({'EXIT', {{badarg,_},_}}, 
       wxEvtHandler:connect(Panel, there_is_no_such_event, [{callback,CB}])),

    ?m(ok, wxWindow:connect(Window, size,[{callback,CB},{userData, window}])),
    ?m(ok, wxWindow:connect(Window, size,[{skip,true},{userData, window}])),

    ?m(true, wxFrame:show(Frame)),

    wxWindow:setSize(Panel, {200,100}),
    wxWindow:setSize(Window, {200,100}),

    get_size_messages(Frame, [frame, panel_cb, window_cb, window]),
    
    wx_test_lib:wx_destroy(Frame, Config).

get_size_messages(_, []) -> ok;    
get_size_messages(Frame, Msgs) ->
    receive 
	#wx{obj=Frame,event=#wxSize{}} ->  %% ok
	    get_size_messages(Frame, lists:delete(frame, Msgs));
	#wx{userData=window, event=#wxSize{}} ->
	    ?m(true, lists:member(window_cb, Msgs)),	   
	    get_size_messages(Frame, lists:delete(window, Msgs));
	#wx{userData=panel, event=#wxSize{}} ->
	    ?m(true, lists:member(panel, Msgs)),	   
	    get_size_messages(Frame, lists:delete(panel, Msgs));
	{got_size,window} ->
	    ?m(false, lists:member(window, Msgs)),
	    get_size_messages(Frame, lists:delete(window_cb, Msgs));
	{got_size,panel} -> 
	    get_size_messages(Frame, lists:delete(panel_cb, Msgs));	
	Other ->
	    ?error("Got unexpected msg ~p ~p~n", [Other,Msgs])
    after 1000 ->
	    ?error("Timeout ~p~n", [Msgs])
    end.

disconnect(TestInfo) when is_atom(TestInfo) -> wx_test_lib:tc_info(TestInfo);
disconnect(Config) ->
    ?mr(wx_ref, wx:new()),
    Frame = ?mt(wxFrame, wxFrame:new(wx:null(), 1, "Event Testing")),
    Panel = ?mt(wxPanel, wxPanel:new(Frame)),

    Tester = self(),
    CB = fun(#wx{event=#wxSize{},userData=UserD}, SizeEvent) ->
		 ?mt(wxSizeEvent, SizeEvent),
		 Tester ! {got_size, UserD}
	 end,
    ?m(ok, wxFrame:connect(Frame,  close_window)),
    ?m(ok, wxFrame:connect(Frame,  size)),
    ?m(ok, wxEvtHandler:connect(Panel, size,[{skip, true},{userData, panel}])),
    ?m(ok, wxEvtHandler:connect(Panel, size,[{callback,CB},{userData, panel}])),

    ?m(true, wxFrame:show(Frame)),

    wxWindow:setSize(Panel, {200,100}),    
    get_size_messages(Frame, [frame, panel_cb]),
    wx_test_lib:flush(),

    ?m(true, wxEvtHandler:disconnect(Panel, size, [{callback,CB}])),
    ?m(ok, wxWindow:setSize(Panel, {200,101})),
    get_size_messages(Frame, [panel]),
    timer:sleep(1000),
    wx_test_lib:flush(),

    ?m({'EXIT', {{badarg,_},_}}, wxEvtHandler:disconnect(Panel, non_existing_event_type)),
    ?m(true, wxEvtHandler:disconnect(Panel, size)),
    ?m(ok, wxWindow:setSize(Panel, {200,102})),
    timer:sleep(1000),
    ?m([], wx_test_lib:flush()),

    wx_test_lib:wx_destroy(Frame, Config).
    


%% Test that the msg events are forwarded as supposed to 
connect_msg_20(TestInfo) 
  when is_atom(TestInfo) -> wx_test_lib:tc_info(TestInfo);
connect_msg_20(Config) ->
    ?mr(wx_ref, wx:new()),
    Frame = ?mt(wxFrame, wxFrame:new(wx:null(), 1, "Event 20 Testing")),
    Tester = self(),
    Env = wx:get_env(),
    
    EvtHandler = fun() ->
			 wx:set_env(Env),
			 wxFrame:connect(Frame,size,[{skip,true}]),
			 Tester ! initiated,
			 receive #wx{obj=Frame,event=#wxSize{}} ->
				 Tester ! got_it
			 end
		 end,
    Msgs = [begin spawn_link(EvtHandler), got_it end|| _ <- lists:seq(1,20)],

    ?m_multi_receive(lists:duplicate(20, initiated)),    
    ?m(true, wxFrame:show(Frame)),

    ?m_multi_receive(Msgs),
    wx_test_lib:wx_destroy(Frame, Config).

%% Test that the callbacks works as msgs
connect_cb_20(TestInfo) 
  when is_atom(TestInfo) -> wx_test_lib:tc_info(TestInfo);
connect_cb_20(Config) ->
    ?mr(wx_ref, wx:new()),
    Frame = ?mt(wxFrame, wxFrame:new(wx:null(), 1, "Event 20 Testing")),
    Tester = self(),
    Env = wx:get_env(),
    
    wxFrame:connect(Frame,size,[{callback, 
				 fun(#wx{event=#wxSize{}},_SizeEv) -> 
					 Tester ! main_got_it
				 end}]),

    EvtHandler = fun() ->
			 wx:set_env(Env),
			 Self = self(),
			 CB = fun(#wx{event=#wxSize{}}, 
				  WxSizeEventObj) ->
				      wxEvent:skip(WxSizeEventObj),
				      Tester ! got_it,
				      Self ! quit
			      end,
			 wxFrame:connect(Frame,size,[{callback, CB}]),
			 Tester ! initiated,
			 receive quit -> ok
			 end
		 end,
    Msgs = [begin spawn_link(EvtHandler), got_it end|| _ <- lists:seq(1,20)],
    
    ?m_multi_receive(lists:duplicate(20, initiated)),
    ?m(true, wxFrame:show(Frame)),
    
    ?m_multi_receive(Msgs),
    ?m_receive(main_got_it),

    wx_test_lib:wx_destroy(Frame, Config).
   

mouse_on_grid(TestInfo) 
  when is_atom(TestInfo) -> wx_test_lib:tc_info(TestInfo);
mouse_on_grid(Config) ->
    Wx = ?mr(wx_ref, wx:new()),
    
    Frame = wxFrame:new(Wx, ?wxID_ANY, "Frame"),
    Panel = wxPanel:new(Frame, []),
    Sizer = wxBoxSizer:new(?wxVERTICAL),
    
    Grid = wxGrid:new(Panel, ?wxID_ANY),
    wxGrid:createGrid(Grid, 10, 10, []),
    wxSizer:add(Sizer, Grid, [{proportion, 1}]),
        
    wxWindow:connect(Panel, motion),
    wxWindow:connect(Panel, middle_down), 

    %% Undocumented function
    GridWindow = ?mt(wxWindow, wxGrid:getGridWindow(Grid)),
    wxWindow:connect(GridWindow, motion),
    wxWindow:connect(GridWindow, middle_down),

    wxWindow:setSizerAndFit(Panel, Sizer),
    wxFrame:show(Frame),
    
    wx_test_lib:wx_destroy(Frame, Config).


spin_event(TestInfo) 
  when is_atom(TestInfo) -> wx_test_lib:tc_info(TestInfo);
spin_event(Config) ->
    Wx = ?mr(wx_ref, wx:new()),

    %% Spin events and scrollEvent share some events id's
    %% test that they work

    Frame = wxFrame:new(Wx, ?wxID_ANY, "Spin Events"),
    Panel = wxPanel:new(Frame, []),
    Sizer = wxBoxSizer:new(?wxVERTICAL),
    HSz = wxBoxSizer:new(?wxHORIZONTAL),

    SB = wxSpinButton:new(Panel, [{id, 100}]),
    wxSizer:add(HSz, SB, []),
    wxSpinButton:connect(SB, spin),
    wxSpinButton:connect(SB, spin_up),
    wxSpinButton:connect(SB, spin_down),

    SC = wxSpinCtrl:new(Panel, [{id, 101}, {min, -12}, {max, 12}, 
				{value, "-3"}, {initial, 3}, 
				{style, ?wxSP_ARROW_KEYS bor ?wxSP_WRAP}]),
    wxSpinCtrl:connect(SC, command_spinctrl_updated),
    wxSizer:add(HSz, SC, [{proportion, 1}, {flag, ?wxEXPAND}]),
    wxSizer:add(Sizer, HSz, [{proportion, 0},{flag, ?wxEXPAND}]),
    
    SL = wxSlider:new(Panel, 102, 57, 22, 99),
    wxSlider:connect(SL, scroll_thumbtrack),
    wxSlider:connect(SL, scroll_lineup),
    wxSlider:connect(SL, scroll_linedown),
    wxSizer:add(Sizer, SL, [{proportion, 0},{flag, ?wxEXPAND}]),
       
    wxWindow:setSizerAndFit(Panel, Sizer),
    wxFrame:show(Frame),
    wx_test_lib:flush(),

%% Set value does not generate a spin event...
%%     wxSpinButton:setValue(SB, 7),
%%     ?m_receive(#wx{id=100, event=#wxSpin{type=spin}}),
%%     wxSpinCtrl:setValue(SC, 8),
%%     ?m_receive(#wx{id=101, event=#wxSpin{type=command_spinctrl_updated}}),
%%     wxSlider:setValue(SL, 29),
%%     ?m_receive(#wx{id=102, event=#wxScroll{}}),

    wx_test_lib:wx_destroy(Frame, Config).


%% Test that we can connect to events from inside a callback fun
%% This is needed for example inside a callback that does a wxWindow:popupMenu/2
connect_in_callback(TestInfo) 
  when is_atom(TestInfo) -> wx_test_lib:tc_info(TestInfo);
connect_in_callback(Config) ->
    Wx = ?mr(wx_ref, wx:new()),
    Frame = wxFrame:new(Wx, ?wxID_ANY, "Connect in callback"),
    Panel = wxPanel:new(Frame, []),
    
    wxFrame:connect(Frame,size,
		    [{callback, 
		      fun(#wx{event=#wxSize{}},_SizeEv) -> 
			      io:format("Frame got size~n",[]),		 
			      F1 = wxFrame:new(Frame, ?wxID_ANY, "Frame size event"),
			      CBPid = self(),
			      wxFrame:connect(F1,size,[{callback,
							fun(_,_) ->
								io:format("CB2 got size~n",[]),
								CBPid ! continue
							end}]),
			      wxWindow:show(F1),
			      receive continue -> wxFrame:destroy(F1) end
		      end}]),
    wxPanel:connect(Panel,size,
		    [{callback, 
		      fun(#wx{event=#wxSize{}},_SizeEv) -> 
			      io:format("Panel got size~n",[]),
			      F1 = wxFrame:new(Frame, ?wxID_ANY, "Panel size event"),
			      wxFrame:connect(F1,size),
			      wxWindow:show(F1),
			      receive #wx{event=#wxSize{}} -> wxFrame:destroy(F1) end
		      end}]),   
    wxFrame:show(Frame),
    wx_test_lib:flush(),
    
    wx_test_lib:wx_destroy(Frame, Config).
