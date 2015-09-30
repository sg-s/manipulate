% manipulate.m
% Mathematica-stype model manipulation
% usage: 
%
% 	manipulate(@fname) % (minimal usage)
% 	manipulate(@fname,'Parameters',p,'stimulus',stimulus,'response',response,'ub',ub,'lb',lb)
%
% where p is a structure containing the parameters of the model you want to manipulate. ub and lb are structures with the same fields as p.  
% The function to be manipulated (fname) should conform to the following standard: 
% 	
% 	[r]=fname(stimulus,p);
%
% where stimulus is an optional matrix that your function might need
% p is a structure containing the parameters you want to manipulate 
% 
% created by Srinivas Gorur-Shandilya at 10:20 , 09 April 2014. Contact me at http://srinivas.gs/contact/
% 
% This work is licensed under the Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License. 
% To view a copy of this license, visit http://creativecommons.org/licenses/by-nc-sa/4.0/.



function manipulate(fname,varargin)

% defensive programming
assert(strcmp(class(fname),'function_handle') | strcmp(class(fname),'char'),'First argument should be a function handle to the model you want to manipulate, or the name of the model you want to manipulate');
if strcmp(class(fname),'char')
	fname = strrep(fname,'.m','');
	eval(['fname=@' fname]); 
end


% defaults
p = getModelParameters(fname);
stimulus = [];
response = [];


if ~nargin 
	help manipulate
	return
else
    if iseven(length(varargin))
    	for ii = 1:2:length(varargin)-1
        	temp = varargin{ii};
        	if ischar(temp)
            	eval(strcat(temp,'=varargin{ii+1};'));
        	end
    	end
	else
    	error('Inputs need to be name value pairs')
	end
end

try
	p = Parameters;
catch
end
mp  =p;

if isempty(p)
	error('Unable to figure out the model parameters. Specify manually')
end



% get bounds from file
[lb, ub] = getBounds(fname);
[pp,valid_fields] = struct2mat(p);

% fit them correctly into vectors 
ub_vec =  Inf*ones(length(fieldnames(p)),1);
lb_vec =  Inf*ones(length(fieldnames(p)),1);

% assign 
assign_these = fieldnames(lb);
for i = 1:length(assign_these)
	assign_this = assign_these{i};
	eval(strcat('this_lb = lb.',assign_this,';'))
	lb_vec(find(strcmp(assign_this,fieldnames(p))))= this_lb;
end
assign_these = fieldnames(ub);
for i = 1:length(assign_these)
	assign_this = assign_these{i};
	eval(strcat('this_ub = ub.',assign_this,';'))
	ub_vec(find(strcmp(assign_this,fieldnames(p))))= this_ub;
end

ub = ub_vec;
lb = lb_vec;

if sum(isinf(lb)) + sum(isinf(ub)) == 2*length(ub)
	lb = (pp/2);
	ub = (pp*2);
	for i = 1:length(lb)
		if lb(i) == ub(i)
			lb(i) = 0;
			ub(i) = 1;
		end
		if lb(i) > ub(i)
			temp = ub(i);
			ub(i) = lb(i);
			lb(i) = temp;
		end
	end
	clear i
else
	lb(isinf(lb)) = 0;
	ub(isinf(ub)) = 1e4;
end

if nargout(fname)
	plotfig = figure('position',[50 250 900 740],'NumberTitle','off','IntegerHandle','off','Name','Manipulate.m','CloseRequestFcn',@QuitManipulateCallback,'Menubar','none');

	modepanel = uibuttongroup(plotfig,'Title','Mode','Units','normalized','Position',[.01 .95 .25 .05]);

	
	mode_time = uicontrol(modepanel,'Units','normalized','Position',[.01 .1 .5 .9], 'Style', 'radiobutton', 'String', 'Time Series','FontSize',10,'Callback',@update_plots);
	mode_fun = uicontrol(modepanel,'Units','normalized','Position',[.51 .1 .5 .9], 'Style', 'radiobutton', 'String', 'Function','FontSize',10,'Callback',@update_plots);

	if ~isempty(stimulus)
		plot_control_string = ['stimulus' argOutNames(fname)];
		for i = 3:length(plot_control_string)
			plot_control_string{i} = strcat('+',plot_control_string{i});
		end
	else
		plot_control_string = argOutNames(fname);
		for i = 2:length(plot_control_string)
			plot_control_string{i} = strcat('+',plot_control_string{i});
		end
	end
	uicontrol(plotfig,'Units','normalized','Position',[.26 .93 .05 .05],'style','text','String','Plot')
	plot_control = uicontrol(plotfig,'Units','normalized','Position',[.31 .935 .15 .05],'style','popupmenu','String',plot_control_string,'Callback',@update_plots,'Tag','plot_control');
	
	if ~isempty(response)
		uicontrol(plotfig,'Units','normalized','Position',[.46 .93 .09 .05],'style','text','String','Response vs.')
		plot_response_here = uicontrol(plotfig,'Units','normalized','Position',[.56 .935 .15 .05],'style','popupmenu','String',argOutNames(fname),'Callback',@update_plots,'Tag','plot_response_here');
	end

	if ~isempty(stimulus)
		show_stim = 1;
	else
		show_stim = 0;
	end
	plot_these = zeros(nargout(fname),1);
	plot_these(1) = 1; % stores which model outputs to plot
	[stimplot,respplot] = make_plots(1+sum(plot_these),show_stim);

	an = argOutNames(fname);
	if ~isempty(response)
		set(plot_response_here,'String',an(find(plot_these)));
	end

else
	stimplot = []; respplot = []; plot_these = [];
end

Height = 440;
controlfig = figure('position',[1000 250 400 Height], 'Toolbar','none','Menubar','none','NumberTitle','off','IntegerHandle','off','CloseRequestFcn',@QuitManipulateCallback,'Name','Manipulate');
axis off

r1 = []; r2 = []; r3 = []; r4 = []; r5 = [];


% declare variables here so that all functions see them
lbcontrol = [];
ubcontrol = [];
control = [];
controllabel = [];
nspacing = [];
saved_state_control = [];

if ~isempty(stimulus)
	% plot the stimulus
	plot(stimplot,stimulus)
	title(stimplot,'Stimulus')
end

RedrawSlider(NaN,NaN);
EvaluateModel2(stimplot,respplot,[]);




function [] = update_plots(src,event)
	% remove all the plots
	delete(stimplot)
	for i = 1:length(respplot)
		delete(respplot(i))
	end

	% first determine which mode we are operating in
	if get(mode_time,'Value')
		if strcmp(get(src,'Tag'),'plot_control')
			% ok. user wants to add/remove a plot. rebuild list of plots 
			if any(strfind(char(plot_control_string(get(src,'Value'))),'+'))
				% need to add this plot
				plot_control_string{get(src,'Value')} = strrep(plot_control_string{get(src,'Value')},'+','');
				if get(src,'Value') > 1
					plot_these(get(src,'Value')-1) = 1;
				else
					show_stim = 1;
				end
			else
				plot_control_string{get(src,'Value')} = strcat('+',plot_control_string{get(src,'Value')});
				if get(src,'Value') > 1
					plot_these(get(src,'Value')-1) = 0;
				else
					show_stim = 0;
				end
			end

			[stimplot,respplot] = make_plots(1+sum(plot_these),show_stim);
			set(plot_control,'String',plot_control_string);
			EvaluateModel2(stimplot,respplot,plot_these);
			an = argOutNames(fname);
			try
				set(plot_response_here,'String',an(find(plot_these)));
			catch
			end
			

		elseif strcmp(get(src,'Tag'),'plot_response_here')
			error('196 not coded')
		elseif strcmp(get(src,'String'),'Time Series')
			if ~isempty(stimulus)
				show_stim = 1;
			end
			[stimplot,respplot] = make_plots(1+sum(plot_these),show_stim);
			set(plot_control,'String',plot_control_string);
			EvaluateModel2(stimplot,respplot,plot_these);
			an = argOutNames(fname);
			try
				set(plot_response_here,'String',an(find(plot_these)));
			catch
			end
		end
	elseif get(mode_fun,'Value')
		show_stim = 0;
		[stimplot,respplot] = make_plots(sum(plot_these),show_stim);
		EvaluateModel2([],respplot,plot_these);
	end
end

function [stimplot,respplot] = make_plots(nplots,show_stim)
	stimplot = []; respplot = [];
	if show_stim
		stimplot = autoPlot(nplots,1,1);
		for i = 2:nplots
			respplot(i-1) = autoPlot(nplots,i,1);
		end

		if nplots > 1
			% link plots
			linkaxes([stimplot respplot],'x');
		end
	else
		for i = 1:nplots
			respplot(i) = autoPlot(nplots,i,1);
		end

		if nplots > 1
			% link plots
			linkaxes(respplot,'x');
		end
	end

end


function  [] = QuitManipulateCallback(~,~)
	try
		delete(plotfig)
	catch
	end
	try
		delete(controlfig)
	catch
	end
end

function [] = EvaluateModel2(stimplot,respplot,event)
	% replacement of Evaluate Model given the near-total rewrite of manipulate
	if nargin(fname) == 2

		% clear all the axes
		for ip = 1:length(respplot)
			cla(respplot(ip))
		end

		an = argOutNames(fname);
		if get(mode_fun,'Value')
			% plot all the data supplied, if any
			hold (respplot(1),'on')
			plot(respplot(1),stimulus,response);

			% now evaluate the function ONCE for a superset of all the stimulus
			this_stim = nonnans(sort(stimulus(:)));
			this_stim = linspace(this_stim(1),this_stim(end),100);

			% evaluate the model
			this_resp = fname(this_stim,p);

			plot(respplot(1),this_stim,this_resp,'k')

		else
			disp('not coded')
		end
	

		if ~isempty(stimulus) && ~isempty(stimplot)
			plot(stimplot,stimulus)
			title(stimplot,'Stimulus')
		end

		
	else
		% just evaluate the model, because the model will handle all plotting 
		p.event = event; % we're also telling the model we are manipulating of the type of event
		eval(strcat(fname,'(p);'))
		p=rmfield(p,'event');
	end		

	% reset the name of the controlfig to indicate that the model has finished running
	set(controlfig,'Name','Manipulate')

end

            

function [] = RedrawSlider(src,event)
	temp=whos('src');
	if ~strcmp(temp.class,'matlab.ui.control.UIControl')

		% draw for the first time
		f = fieldnames(p);
		f=f(valid_fields);

		% pvec = struct2mat(p);
		pvec = (ub+lb)/2;
		
		nspacing = Height/(length(f)+1);
		for i = 1:length(f)

			% if pvec(i) > lb(i) && pvec(i) < ub(i)
			% else
			% 	lb(i) = pvec(i) - 1;
			% 	ub(i) = pvec(i) + 1;
			% end	
			control(i) = uicontrol(controlfig,'Position',[70 Height-i*nspacing 230 20],'Style', 'slider','FontSize',12,'Callback',@SliderCallback,'Min',lb(i),'Max',ub(i),'Value',pvec(i));
			try    % R2013b and older
			   addlistener(control(i),'ActionEvent',@SliderCallback);
			catch  % R2014a and newer
			   addlistener(control(i),'ContinuousValueChange',@SliderCallback);
			end
			% hat tip: http://undocumentedmatlab.com/blog/continuous-slider-callback
			thisstring = strkat(f{i},'=',mat2str(eval(strcat('p.',f{i}))));
			controllabel(i) = uicontrol(controlfig,'Position',[10 Height-i*nspacing 50 20],'style','text','String',thisstring);
			lbcontrol(i) = uicontrol(controlfig,'Position',[300 Height-i*nspacing+3 40 20],'style','edit','String',mat2str(lb(i)),'Callback',@RedrawSlider);
			ubcontrol(i) = uicontrol(controlfig,'Position',[350 Height-i*nspacing+3 40 20],'style','edit','String',mat2str(ub(i)),'Callback',@RedrawSlider);
		end
		clear i
		uicontrol(controlfig,'Position',[10 Height-length(f)*nspacing-30 100 20],'style','pushbutton','String','+State','Callback',@export);
		saved_state_string = {};
		if length(mp) > 0
			for i = 1:length(mp)
				saved_state_string{i} = strcat('State',mat2str(i));
			end
		else
			saved_state_string = 'No Saved states.';
		end
		saved_state_control = uicontrol(controlfig,'Position',[110 Height-length(f)*nspacing-30 150 20],'style','popupmenu','String',saved_state_string,'Callback',@go_to_saved_state);

		remove_saved_state_control = uicontrol(controlfig,'Position',[260 Height-length(f)*nspacing-30 100 20],'style','pushbutton','String','-State','Callback',@remove_saved_state);

	else
		% find the control that is being changed
		this_control=[find(lbcontrol==src) find(ubcontrol==src)];

		this_lb = str2double(get(lbcontrol(this_control),'String'));
		this_ub = str2double(get(ubcontrol(this_control),'String'));
		this_slider = get(control(this_control),'Value');

		if this_slider > this_ub || this_slider < this_lb 
			this_slider = (this_ub - this_lb)/2 + this_lb;
			set(control(this_control),'Value',this_slider);
		end

		% change the upper and lower bounds of this slider
		set(control(this_control),'Min',str2num(get(lbcontrol(this_control),'String')));
		set(control(this_control),'Max',str2num(get(ubcontrol(this_control),'String')));

	end
end         

function [] = go_to_saved_state(~,event)
	this_state = get(saved_state_control,'Value');
	p = mp(this_state);

	% Evaluate the model
	EvaluateModel2(stimplot,respplot,event);

	% fix all the slider positions
	f = fieldnames(p);
	f=f(valid_fields);

	for i = 1:length(controllabel)
		thisstring = strkat(f{i},'=',oval(eval(strcat('p(length(p)).',f{i})),2));

		% update the label
		set(controllabel(i),'String',thisstring);
	end
end

function []  = remove_saved_state(~,~)
	this_state = get(saved_state_control,'Value');
	mp(this_state) = [];
	f = fieldnames(p);
	f=f(valid_fields);
	% update saved states
	saved_state_string = {};
	if length(mp) > 0
		for i = 1:length(mp)
			saved_state_string{i} = strcat('State',mat2str(i));
		end
	else
		saved_state_string = 'No Saved states.'
	end
	set(saved_state_control,'String',saved_state_string,'Value',1)
end


function [] = export(~,~)
	if isempty(mp)
		mp = p;
	else
		mp(length(mp)+1) = p;
	end
	assignin('base','p',mp)

	% update saved states
	saved_state_string = {};
	if length(mp) > 0
		for i = 1:length(mp)
			saved_state_string{i} = strcat('State',mat2str(i));
		end
	else
		saved_state_string = 'No Saved states.'
	end
	set(saved_state_control,'String',saved_state_string)

end


function  [] = SliderCallback(src,event)

	% figure out which slider was moved
	this_slider = find(control == src);

	% update the value
	f = fieldnames(p(length(p)));
	f=f(valid_fields);
	
	thisval = get(control(this_slider),'Value');
	eval((strcat('p(length(p)).',f{this_slider},'=thisval;')));
	thisstring = strkat(f{this_slider},'=',oval(eval(strcat('p(length(p)).',f{this_slider})),2));

	% update the label
	controllabel(this_slider) = uicontrol(controlfig,'Position',[10 Height-this_slider*nspacing 50 20],'style','text','String',thisstring);

	% disable all the sliders while the model is being evaluated
	set(control,'Enable','off')
	set(controlfig,'Name','...')

	% evalaute the model and update the plot
	EvaluateModel2(stimplot,respplot,event)

	% re-enable all the sliders
	set(control,'Enable','on')


end


end