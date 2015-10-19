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
assert(length(argOutNames(fname))<6,'manipualte::the function to be manipulated cannot have more than 5 outputs')

% read preferences from preferences file (pref.m)
pref = readPref;

% defaults
Parameters = getModelParameters(fname);
stimulus = [];
response = [];


% these are placeholders that will store all the responses from the model
model_props.arg_out_names = argOutNames(fname);
model_props.n_outputs = length(argOutNames(fname));
all_plot_handles = NaN(model_props.n_outputs,1); % array containing handles to axes showing model outputs. the first is reserved for the stimulus
plot_control_string = '';

r1 = []; r2 = []; r3 = []; r4 = []; r5 = [];


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
mp = p;

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
	if pref.debug_mode
		disp('Function being manipulated has non-zero outputs. So manipulate will make a GUI to show all of this.')
	end


	plotfig = figure('position',[50 250 900 740],'NumberTitle','off','IntegerHandle','off','Name','Manipulate.m','CloseRequestFcn',@quitManipulateCallback);

	modepanel = uibuttongroup(plotfig,'Title','Mode','Units','normalized','Position',[.01 .95 .25 .05]);
	mode_time = uicontrol(modepanel,'Units','normalized','Position',[.01 .1 .5 .9], 'Style', 'radiobutton', 'String', 'Time Series','FontSize',10,'Callback',@updatePlotLabels);
	mode_fun = uicontrol(modepanel,'Units','normalized','Position',[.51 .1 .5 .9], 'Style', 'radiobutton', 'String', 'Function','FontSize',10,'Callback',@updatePlotLabels);

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
	plot_control = uicontrol(plotfig,'Units','normalized','Position',[.31 .935 .15 .05],'style','popupmenu','String',plot_control_string,'Callback',@updatePlotLabels,'Tag','plot_control');
	
	if ~isempty(response)
		uicontrol(plotfig,'Units','normalized','Position',[.46 .93 .09 .05],'style','text','String','Response vs.')
		plot_response_here = uicontrol(plotfig,'Units','normalized','Position',[.56 .935 .15 .05],'style','popupmenu','String',argOutNames(fname),'Callback',@updatePlotLabels,'Tag','plot_response_here');
	end

	makePlotsGUI;

	an = argOutNames(fname);
	if ~isempty(response)
		set(plot_response_here,'String',an(find(plot_these)));
	end

else
	if pref.debug_mode
		disp('manipualte::Function to be manipualted has no outputs. I will assume that it will handle its own plotting')
	end
end

Height = 440;
controlfig = figure('position',[1000 250 400 Height], 'Toolbar','none','Menubar','none','NumberTitle','off','IntegerHandle','off','CloseRequestFcn',@quitManipulateCallback,'Name','Manipulate');
axis off

% declare variables here so that all functions see them
lbcontrol = [];
ubcontrol = [];
control = [];
controllabel = [];
nspacing = [];
saved_state_control = [];

if ~isempty(stimulus)
	% plot the stimulus
	plot(all_plot_handles(1),stimulus)
	title(all_plot_handles(1),'Stimulus')
end

redrawSlider(NaN,NaN);
evaluateModel;


function updatePlotLabels(src,event)
	if any(strfind(src.String{src.Value},'+'))
		src.String{src.Value} = strrep(src.String{src.Value},'+','');
	else
		src.String{src.Value} = ['+' src.String{src.Value}];
	end

	makePlotsGUI;

end

function makePlotsGUI()
	
	% first clear the figure of all previous plots
	try
		for i = 1:length(all_plot_handles)
			try
				delete(all_plot_handles(i))
			end
		end
	end

	all_plot_handles = NaN(length(plot_control_string),1);

	% first figure out how many plots to make in total. this is determines by how many items in plot_control_string exist without a "+" before them
	plot_control_string = plot_control.String;
	plot_these = false(length(plot_control_string),1);
	for i = 1:length(plot_control_string)
		if isempty(strfind(plot_control_string{i},'+'))
			plot_these(i) = true;
		end
	end


	c = 1;
	for i = 1:length(plot_these)
		if plot_these(i)
			all_plot_handles(i) = autoPlot(sum(plot_these),c,1);
			c = c + 1;
			if i == 1
				% stimulus
				plot(all_plot_handles(1),stimulus)
				title(all_plot_handles(1),'Stimulus')
			else
				% response
				title(all_plot_handles(i),model_props.arg_out_names{i-1})
			end
				
		end
	end
	linkaxes(all_plot_handles,'x')

end


function  [] = quitManipulateCallback(~,~)
	try
		delete(plotfig)
	catch
	end
	try
		delete(controlfig)
	catch
	end
end

function [] = evaluateModel(event)


	if nargin(fname) == 2
		if pref.debug_mode
			disp('manipulate::function we are manipulating has two inputs, assuming that they are stimulus and parameter structure')
		end

		if get(mode_fun,'Value')
			if pref.debug_mode
				disp('manipulate::function manipulation mode. Not coded')
				keyboard
			end
			hold (respplot(1),'on')
			plot(respplot(1),stimulus,response);

			% now evaluate the function ONCE for a superset of all the stimulus
			this_stim = nonnans(sort(stimulus(:)));
			this_stim = linspace(this_stim(1),this_stim(end),100);

			% evaluate the model
			this_resp = fname(this_stim,p);

			plot(respplot(1),this_stim,this_resp,'k')
			

		else
			if pref.debug_mode
				disp('manipulate::model manipulation mode.')
			end
			% evaluate the model and get all outputs
			es = '[';
			for i = 1:length(argOutNames(fname))
				es = [es 'r', mat2str(i) ,','];
			end
			es(end) = '';
			es = [es ']=' char(fname) ,'(stimulus,p);'];
			eval(es);
			% OK, now we have all the outputs from the model. plot what is necessary where needed:
			plot_control_string = plot_control.String;
			for i = 2:length(plot_control_string)
				if isempty(strfind(plot_control_string{i},'+'))
					cla(all_plot_handles(i))
					eval(['plot(all_plot_handles(i),r',mat2str(i-1),');'])
					title(all_plot_handles(i),plot_control_string{i})
					this_resp = [];
					eval(['this_resp = r' mat2str(i-1),';']);
					z = floor(length(this_resp)/2);
					try
						set(all_plot_handles(i),'YLim',[min(this_resp(z:end)) max(this_resp(z:end))])
					catch
						% probably an error where the plot is shit, with NaNs, or flat
					end
				end
			end
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

            

function [] = redrawSlider(src,event)
	temp=whos('src');
	if ~strcmp(temp.class,'matlab.ui.control.UIControl')

		% draw for the first time
		f = fieldnames(p);
		f=f(valid_fields);

		pvec = (ub+lb)/2;
		
		nspacing = Height/(length(f)+1);
		for i = 1:length(f)
			control(i) = uicontrol(controlfig,'Position',[70 Height-i*nspacing 230 20],'Style', 'slider','FontSize',12,'Callback',@sliderCallback,'Min',lb(i),'Max',ub(i),'Value',pvec(i));
			if pref.live_update
				try    % R2013b and older
				   addlistener(control(i),'ActionEvent',@sliderCallback);
				catch  % R2014a and newer
				   addlistener(control(i),'ContinuousValueChange',@sliderCallback);
				end
			end
			% hat tip: http://undocumentedmatlab.com/blog/continuous-slider-callback
			thisstring = strkat(f{i},'=',mat2str(eval(strcat('p.',f{i}))));
			controllabel(i) = uicontrol(controlfig,'Position',[10 Height-i*nspacing 50 20],'style','text','String',thisstring);
			lbcontrol(i) = uicontrol(controlfig,'Position',[300 Height-i*nspacing+3 40 20],'style','edit','String',mat2str(lb(i)),'Callback',@redrawSlider);
			ubcontrol(i) = uicontrol(controlfig,'Position',[350 Height-i*nspacing+3 40 20],'style','edit','String',mat2str(ub(i)),'Callback',@redrawSlider);
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
		saved_state_control = uicontrol(controlfig,'Position',[110 Height-length(f)*nspacing-30 150 20],'style','popupmenu','String',saved_state_string,'Callback',@goToSavedState);

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

function [] = goToSavedState(~,event)
	this_state = get(saved_state_control,'Value');
	p = mp(this_state);

	% Evaluate the model
	evaluateModel(event);

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


function  [] = sliderCallback(src,event)

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
	evaluateModel(event)

	% re-enable all the sliders
	set(control,'Enable','on')


end


end