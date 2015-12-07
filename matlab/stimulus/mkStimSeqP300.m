function [stimSeq,stimTime,eventSeq,colors]=mkStimSeqP300(nSymbs,duration,isi,tti,oddp)
% make a P300/oddball type of stimulus sequence
%
% [stimSeq,stimTime,eventSeq,stimCode]=mkStimSeqP300(nSymbs,duration,isi,mintti,oddp)
%
%  The stimSeq generated has the property that the same symbol will not flash again within
%  mittti seconds
%
% Inputs:
%  nSymbs -- [int] number of symbols to make the sequence for
%  duration  -- [int] duration of the stimulus in seconds
%  isi    -- [float] inter-stimulus interval in seconds                (1)
%  tti    -- [float] target-to-target interval, add non-stim events to ensure this many seconds
%                on average between highlighing this symbol
%  oddp   -- [bool] oddball, i.e. 3 stimulus types = target/standard/distractor, paradigm?
%                   all non-flashed stimuli have distractor value.
% Outputs:
%  stimSeq  -- [bool nSymbs x nStim] logical matrix with true indicating that this symbol 
%                       should flashed at this time
%  stimTime -- [1 x nStim] time in seconds each stimulus event should take place
%  eventSeq -- {1 x nStim} cell array containing {2x1} event info which should be sent at each stimulus time.
%                   Each entry is either empty (i.e. {}) indicating no event to be sent or
%                   {type value} a cell array with the event type and value to send
if ( numel(nSymbs)>1 ) nSymbs=numel(nSymbs); end;
if ( nargin<2 || isempty(duration) ) duration=3; end; % default to 3sec
if ( nargin<3 || isempty(isi) )  isi=1/5; end;        % default to 5hz
if ( nargin<4 || isempty(tti) )  tti =1; end;         % default to ave target every second
if ( nargin<5 || isempty(oddp) ) oddp=false; end;
% make a simple visual intermittent flash stimulus
colors=[1 1 1;...  % color(1) = flash
        0 1 0]';   % color(2) = target
nStim = duration/isi;
stimTime=(1:nStim)*isi(1); % event every isi
stimSeq =-ones(nSymbs,numel(stimTime)); % make stimSeq where everything is turned off
if ( oddp ) 
  colors=[0  1  0;...   % flash
          0  1  0;...   % target
          .7 .7 .7]';   % std - approx iso-luminant
  stimSeq(:,2:2:end)=3; % every stimulus event
end
eventSeq=cell(numel(stimTime),1);
tti_ev = ceil(tti/isi);
flashStim=zeros(nSymbs,1);
for stimi=1:nSymbs;
  flashStim(:)=0; 
  if ( oddp ) flashStim(:)=3; end;
  flashStim(stimi)=1; % flash only has symbol 1 set
  si=0;
  while (si<numel(stimTime)) % loop to find a flash time not at the same time as another symbol
	 if ( si==0 ) sstart=0; else sstart=si+ceil(tti_ev/2); end
	 possIdx = sstart+(1:tti_ev);
	 if ( isempty(possIdx) || possIdx(1)>numel(stimTime) ) break; end
	 emptyPos = stimSeq(:,possIdx(possIdx<numel(stimTime)));
	 if ( oddp )  emptyPos = all(emptyPos==3,1); else emptyPos=all(emptyPos<=0,1); end;
	 if ( any(emptyPos) ) % use one of the empty slots
		possIdx = possIdx(emptyPos);
	 end	 
	 si = possIdx(randi(numel(possIdx))); % now randomly pick one of the possibilties
    if ( oddp ) si=2*ceil(si/2); end;	 
	 if ( si>numel(stimTime) ) break; end;
	 % and insert into the stimSeq
	 if ( ~any(stimSeq(:,si)==1) ) 	stimSeq(:,si)     = flashStim;
	 else                            stimSeq(stimi,si) = 1;
	 end
  end
end
return;
%----------------------
function testCase();
% binary
[stimSeq,stimTime]=mkStimSeqP300(10,10,1/10,2,1);
clf;imagesc('cdata',stimSeq)
clf;playStimSeq(stimSeq,stimTime)