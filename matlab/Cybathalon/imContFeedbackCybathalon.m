configureIM;

cybathalon = struct('host','localhost','port',5555,'player',1,...
                    'cmdlabels',{{'speed' 'rest' 'jump' 'kick'}},'cmddict',[1 99 2 3],...
                    'socket',[]);
% open socket to the cybathalon game
[cybathalon.socket]=javaObject('java.net.DatagramSocket'); % create a UDP socket
cybathalon.socket.connect(javaObject('java.net.InetSocketAddress',cybathalon.host,cybathalon.port)); % connect to host/port

% make the target sequence
tgtSeq=mkStimSeqRand(nSymbs,nSeq);

% make the stimulus display
fig=figure(2);
clf;
set(fig,'Name','Imagined Movement','color',winColor,'menubar','none','toolbar','none','doublebuffer','on');
ax=axes('position',[0.025 0.025 .95 .95],'units','normalized','visible','off','box','off',...
        'xtick',[],'xticklabelmode','manual','ytick',[],'yticklabelmode','manual',...
        'color',winColor,'DrawMode','fast','nextplot','replacechildren',...
        'xlim',[-1.5 1.5],'ylim',[-1.5 1.5],'Ydir','normal');

stimPos=[]; h=[];
stimRadius=diff(axLim)/4;
cursorSize=stimRadius/2;
theta=linspace(0,2*pi,nSymbs+1);
if ( mod(nSymbs,2)==1 ) theta=theta+pi/2; end; % ensure left-right symetric by making odd 0=up
theta=theta(1:end-1);
stimPos=[cos(theta);sin(theta)];
for hi=1:nSymbs; 
  h(hi)=rectangle('curvature',[1 1],'position',[stimPos(:,hi)-stimRadius/2;stimRadius*[1;1]],...
                  'facecolor',bgColor); 
end;
% add symbol for the center of the screen
stimPos(:,nSymbs+1)=[0 0];
h(nSymbs+1)=rectangle('curvature',[1 1],'position',[stimPos(:,end)-stimRadius/4;stimRadius/2*[1;1]],...
                      'facecolor',bgColor); 
set(gca,'visible','off');

%Create a text object with no text in it, center it, set font and color
set(fig,'Units','pixel');wSize=get(fig,'position');set(fig,'units','normalized');% win size in pixels
txthdl = text(mean(get(ax,'xlim')),mean(get(ax,'ylim')),' ',...
				  'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle',...
				  'fontunits','pixel','fontsize',.05*wSize(4),...
				  'color',[0.75 0.75 0.75],'visible','off');

set(txthdl,'string', 'Click mouse when ready', 'visible', 'on'); drawnow;
waitforbuttonpress;
set(txthdl,'visible', 'off'); drawnow;

% play the stimulus
set(h(:),'facecolor',bgColor);
sendEvent('stimulus.testing','start');
% initialize the state so don't miss classifier prediction events
state=[]; 
endTesting=false; dvs=[];
for si=1:nSeq;

  if ( ~ishandle(fig) || endTesting ) break; end;
  
  sleepSec(intertrialDuration);
  % show the screen to alert the subject to trial start
  set(h(:),'faceColor',bgColor);
  set(h(end),'facecolor',fixColor); % red fixation indicates trial about to start/baseline
  drawnow;% expose; % N.B. needs a full drawnow for some reason
  sendEvent('stimulus.baseline','start');
  sleepSec(baselineDuration);
  sendEvent('stimulus.baseline','end');

  % show the target
  fprintf('%d) tgt=%d : ',si,find(tgtSeq(:,si)>0));
  set(h(tgtSeq(:,si)>0),'facecolor',tgtColor);
  set(h(tgtSeq(:,si)<=0),'facecolor',bgColor);
  if ( ~isempty(symbCue) )
	 set(txthdl,'string',sprintf('%s ',symbCue{tgtSeq(:,si)>0}),'color',[.1 .1 .1],'visible','on');
  end
  set(h(end),'facecolor',tgtColor); % green fixation indicates trial running
  drawnow;% expose; % N.B. needs a full drawnow for some reason
  ev=sendEvent('stimulus.target',find(tgtSeq(:,si)>0));
  sendEvent('stimulus.trial','start',ev.sample);
  state=buffer('poll'); % Ensure we ignore any predictions before the trial start  

  
  %------------------------------- trial interval --------------
  % for the trial duration update the fixatation point in response to prediction events
  % initial fixation point position
  fixPos = stimPos(:,end);
  state  = [];
  preds  = []; % buffer of all predictions since trial start
  dv     = zeros(nSymbs,1);
  prob   = ones(nSymbs,1)./nSymbs; % start with equal prob over everything
  trlStartTime=getwTime();
  timetogo = contFeedbackTrialDuration;
  nevt=0;
  evtTime=trlStartTime+epochDuration; % N.B. already sent the 1st target event
  while (timetogo>0) % loop until the trail end
	 curTime  = getwTime();
    timetogo = contFeedbackTrialDuration - (curTime-trlStartTime); % time left to run in this trial
    % wait for new prediction events to process *or* end of trial time
    [events,state,nsamples,nevents] = buffer_newevents(buffhost,buffport,state,'classifier.prediction',[],min([epochDuration,evtTime-curTime,timetogo])*1000);
    if ( isempty(events) ) 
		if ( timetogo>.1 ) fprintf('%d) no predictions!\n',nsamples); end;
    else
		[ans,si]=sort([events.sample],'ascend'); % proc in *temporal* order
      for ei=1:numel(events);
        ev=events(si(ei));% event to process        
		  %fprintf('pred-evt=%s\n',ev2str(ev));
        dv=ev.value;
        % accumulate all predictions
        preds=[preds dv];
        
        % convert from dv to normalised probability
        prob=exp((dv-max(dv))); prob=prob./sum(prob); % robust soft-max prob computation
        if ( verb>=0 ) 
			 fprintf('%d) dv:[%s]\tPr:[%s]\n',ev.sample,sprintf('%5.4f ',pred),sprintf('%5.4f ',prob));
        end;
      end

	 end % if prediction events to process

    % convert from dv to normalised probability
    dv  =mean(preds,2); % feedback is average prediction since trial start
    prob=exp((dv-max(dv))); prob=prob./sum(prob); % robust soft-max prob computation

    % feedback information... simply move in direction detected by the BCI
	 if ( numel(prob)>=size(stimPos,2)-1 ) % per-target decomposition
      if(numel(prob)>size(stimPos,2)) prob=[prob(1:size(stimPos,2)-1);sum(prob(size(stimPos,2):end))];end
		dx = stimPos(:,1:numel(prob))*prob(:); % change in position is weighted by class probs
	 end
    fixPos   =dx; % new fix pos is weighted by classifier output
    %move the fixation to reflect feedback
    cursorPos=get(h(end),'position'); cursorPos=cursorPos(:);
	 set(h(end),'position',[fixPos-.5*cursorPos(3:4);cursorPos(3:4)]);
    drawnow; % update the display after all events processed    
  end % while time to go

						  %------------------------------- feedback --------------
  if ( isempty(preds) ) 
    fprintf(1,'Error! no predictions after %gs, continuing (%d samp, %d evt)\n',trlEndTime-trlStartTime,state.nSamples,state.nEvents);
    set(h(:),'facecolor',bgColor);
    set(h(end),'facecolor',fbColor); % fix turns blue to show now pred recieved
    drawnow;
  
  else
     % average of the predictions is used for the final decision
     dv = mean(preds,2);
     prob=exp((dv-max(dv))); prob=prob./sum(prob); % robust soft-max prob computation
    
     [ans,predTgt]=max(dv); % prediction is max classifier output
     set(h(:),'facecolor',bgColor);
     set(h(predTgt),'facecolor',fbColor);
     drawnow;
     sendEvent('stimulus.predTgt',predTgt);
     % send the command to the game server
     cybathalon.socket.send(uint8(10*cybathalon.player+cybathalon.cmddict(predTgt)),1);

  end % if classifier prediction
  sleepSec(feedbackDuration);
  
  % reset the cue and fixation point to indicate trial has finished  
  set(h(:),'facecolor',bgColor);
  if ( ~isempty(symbCue) ) set(txthdl,'visible','off'); end
  % also reset the position of the fixation point
  drawnow;
  sendEvent('stimulus.trial','end');
  
end % loop over sequences in the experiment
% end training marker
sendEvent('stimulus.testing','end');

if ( ishandle(fig) ) % thanks message
set(txthdl,'string',{'That ends the testing phase.','Thanks for your patience'}, 'visible', 'on', 'color',[0 1 0]);
pause(3);
end
