%% Analysis script
% Written by D.B. Heyer
close all, clear all

%% Set path to load and save data
%basedir = 'D:\Morphys\Data\Labbooks\NAG\MetadataABF' ;
basedir = 'C:\Users\DBHeyer\Documents\PhD\Human Database\Morphys\Data\Labbooks\NAG\MetadataABF' ;
savename = 'DataSummaryNAG2.mat' ;

%% import CSV files
% requires specific folder- and filenames in location basedir!
abfs = readtable(fullfile(basedir, 'Abffiles','Abffiles.txt')) ;
channels = readtable(fullfile(basedir, 'Channels','Channels.txt')) ;
ins = readtable(fullfile(basedir, 'Analogins','Analogins.txt')) ;
sweeps = readtable(fullfile(basedir, 'Sweeps','Sweeps.txt')) ;
epochs = readtable(fullfile(basedir, 'Epochs','Epochs.txt')) ;
aps = readtable(fullfile(basedir, 'Actionpotentials','Actionpotentials.txt')) ;

%% Loop through abfs
index = 1 ;
for i = 1:height(abfs)
    %% Make subset of data per abf file
    fprintf('Looking for CC-step protocols: file nr %1.0f \n', i);
    abf = SubsetTable2struct(abfs(i,:),channels,ins,sweeps,epochs,aps) ;
    %% If abf is a stepprotocol: continue with analysis
    if isccstep(abf) 
        fprintf('Retrieving analysis parameters from CC-step file %1.0f \n', index);
        %% Analyze
        sweep = abf.channel.in.sweep ;
        NrofSweeps = length(sweep) ;  
        % find current injection epoch and assign aps to sweep
        for step = 1:length(sweep(1).epoch)
            if sweep(1).epoch(step).stepdiff < 0 && (sweep(1).epoch(step).stepdiff + sweep(1).epoch(step+1).stepdiff) == 0
                break
            end
        end
        for j = 1:NrofSweeps
            sweep(j).vmbase = sweep(j).epoch(step-1).steadystate ;
            sweep(j).currinj = sweep(j).epoch(step).stepdiff ;
            sweep(j).vmresponse = sweep(j).epoch(step).vstep ;
            sweep(j).ap = sweep(j).epoch(step).ap ;
            for ap = 1:length(sweep(j).epoch(step+1).ap)
                if sweep(j).epoch(step+1).ap(ap).start_time > (sum(second({sweep(1).epoch(1:step).timespan}))*1000)+7 && sweep(j).epoch(step+1).ap(ap).start_time < (sum(second({sweep(1).epoch(1:step).timespan}))*1000)+300
                    sweep(j).rbap(ap) = sweep(j).epoch(step+1).ap(ap) ;
                end
            end
        end
        % find rheobase sweep
        for frstspikeswp = 1:NrofSweeps
            if sweep(frstspikeswp).epoch(step).nrofaps > 0 && sweep(frstspikeswp).epoch(step).stepdiff > 0
                break
            end
        end
        % find trainsweep 
        TrainCurr = sweep(frstspikeswp).epoch(step).stepdiff +50 ;
        for j = 1:NrofSweeps
            tmp(j) = abs(sweep(j).epoch(step).stepdiff - TrainCurr) ;
        end

        [TrSwp TrSwp] = min(tmp) ;
        CurrAbvRheo=NaN;
        for TrainSweep = TrSwp:NrofSweeps      
            if length(sweep(TrainSweep).ap) > 3           
                CurrAbvRheo = sweep(TrainSweep).epoch(step).stepdiff - (TrainCurr-50) ;
                TrSweepCrit=1;
                break
            elseif TrainSweep==NrofSweeps
                TrSweepCrit=0;
            end  
        end

        % calculate variables
        vmbase = [sweep.vmbase] ;
        Freqs=[];
        StimInts=[];
        for j = 1:NrofSweeps           
            if sweep(j,1).currinj >= -100 && sweep(j,1).currinj < 0
                voltageResponses(j,1) = sweep(j,1).vmresponse ; 
                currInjections_R(j,1) = sweep(j,1).currinj ;
                if sweep(j,1).epoch(step).tau < 100 && sweep(j,1).epoch(step).tau > 0
                    taus(j,1) = sweep(j,1).epoch(step).tau ;
                else
                    taus(j,1) = NaN;
                end
            end       

            if ~isempty(sweep(j,1).vmresponse) 
                MinVmResponse(j,1) = sweep(j,1).vmresponse ;
                PkDeflect(j,1) = sweep(j,1).vmbase - sweep(j,1).vmresponse ;
            end        

            if sweep(j,1).currinj > 0
                NrofAPs(j,1) = length(sweep(j,1).ap) ;  
            end
            if sweep(j,1).currinj < 0 && isfield(sweep, 'rbap')
                NrofRBAPs(j,1) = length(sweep(j,1).rbap) ;
            else
                NrofRBAPs(j,1) = 0 ;
            end

            if length(sweep(j).ap) >= 4 && sweep(j,1).currinj > 0
                Freqs(j,1) =  mean([sweep(j).ap(4:end).freq]) ;
                StimInts(j,1) = [sweep(j,1).currinj] ;
            end         
        end

        if sum(NrofRBAPs) > 0
            NrofRBAPsM = mean(NrofRBAPs(NrofRBAPs~=0)) ;
        else
            NrofRBAPsM = 0 ;
        end
        
        for l = 1:length(sweep(TrainSweep).ap)           
            if ~isempty(sweep(TrainSweep).ap(l,1).halfwidth)
                HWsTS(l,1) = [sweep(TrainSweep).ap(l,1).halfwidth] ;  
            end       
        end

  
        if TrSweepCrit==1
            TSbasetothresh = ([sweep(TrainSweep).ap.thresh]-sweep(TrainSweep).vmbase) ;
            TSpeaktoahp = ([sweep(TrainSweep).ap.ahp_time]-[sweep(TrainSweep).ap.peak_time]) ;
            AmpsTSthresh = [sweep(TrainSweep).ap.amp] ;
            AHPsTS = [sweep(TrainSweep).ap.relahp] ;
            ISIsTS = [sweep(TrainSweep).ap(2:end).isi] ;
            FreqTrSwp = mean([sweep(TrainSweep).ap(4:end).freq]) ;
            NrOfAPsTrSwp = length(sweep(TrainSweep).ap) ; 
            OnsetTSFAP = sweep(TrainSweep).ap(1).thresh_time - (sum(second({sweep(TrainSweep).epoch(1:step-1).timespan}))*1000) ;
        else
            TSbasetothresh = NaN;
            TSpeaktoahp = NaN;
            AmpsTSthresh = NaN;
            AHPsTS = NaN;
            ISIsTS = NaN;
            FreqTrSwp = NaN;
            NrOfAPsTrSwp = NaN;
            OnsetTSFAP = NaN;
        end

        % calculate input resistance     
        f_R=fittype('R*x+b');
        tmp=length(find(currInjections_R~=0 & ~isnan(voltageResponses)));
        if tmp > 1         
            [fitR]=fit(currInjections_R(currInjections_R~=0 & ~isnan(voltageResponses)),voltageResponses(voltageResponses~=0 & ~isnan(voltageResponses)),f_R, 'StartPoint', [0 0]); 
            Rin=fitR.R*1e3; % In mOhm
        elseif tmp ==1  % If there is only one point, use that to calculate Rin directly:
            Rin=voltageResponses(voltageResponses~=0 & ~isnan(voltageResponses))/currInjections_R(currInjections_R~=0 & ~isnan(voltageResponses))*1e3;
        else
            Rin=NaN;
        end
        % determine sweep for sag, (minimum voltage response closest to -100)
        tmp = abs(MinVmResponse+100) ;
        [sagswp sagswp] = min(tmp) ;

        % calculate input frequency curve
        Freqs = Freqs(Freqs~=0) ;
        StimInts = StimInts(StimInts~=0) ;
        if length(Freqs) > 1
            [fitFi]=fit(StimInts,Freqs,f_R, 'StartPoint', [0 0]); 
            FrqChngStimInt = fitFi.R ;
        else  
            FrqChngStimInt = NaN ;   
        end

        % bursting & adaptation index
        if length(ISIsTS) > 2
            ISIRatio1toAll = mean(ISIsTS(2:end)) / mean(ISIsTS(1)) ;
            N = length(ISIsTS)-1 ;
            for n = 1:N
                ISIchanges(n,1) = (ISIsTS(n+1)-ISIsTS(n)) / (ISIsTS(n+1)+ISIsTS(n));
            end
            AdaptIdx = (1/N)*sum(ISIchanges) ;        
        else
            ISIRatio1toAll = NaN;
            AdaptIdx = NaN;
        end
        
        % Amplitude accomodation
        if length(AmpsTSthresh) > 2           
            N = length(AmpsTSthresh)-1 ;
            for n = 1:N
                Ampchanges(n,1) = (AmpsTSthresh(n+1)-AmpsTSthresh(n)) / (AmpsTSthresh(n+1)+AmpsTSthresh(n));
                HWchanges(n,1) = (HWsTS(n+1)-HWsTS(n)) / (HWsTS(n+1)+HWsTS(n));
            end
            AmpAccom = (1/N)*sum(Ampchanges) ;  
            HWAccom = (1/N)*sum(HWchanges) ;
        else
            AmpAccom = NaN;    
            HWAccom = NaN; 
        end        
        

        %% Create summary  
        Summary(index).File               = abf.filename ;
        Summary(index).Date               = abf.filetimestart ;
        Summary(index).UserID             = abf.userid ;
        Summary(index).guid               = abf.guid ;
        Summary(index).Channel            = abf.channel.in.number ;
        Summary(index).NrofSweeps         = NrofSweeps ;
        Summary(index).PDur               = second(sweep(1).epoch(step).timespan)*1000 ;
        Summary(index).FrstP              = sweep(1).currinj ;
        Summary(index).DeltaP             = sweep(2).currinj - sweep(1).currinj ;
        Summary(index).Rheobase           = sweep(frstspikeswp).currinj ;
        Summary(index).FrstSpikeSwp       = frstspikeswp ; 
        Summary(index).TrainSwp           = TrainSweep ; 
        Summary(index).CurrAbvRheo        = CurrAbvRheo ;
        Summary(index).vmbaseM            = nanmean(vmbase) ;
        Summary(index).vmbaseSD           = nanstd(vmbase) ;
        Summary(index).InputR             = Rin ;% in MOhm...
        Summary(index).FreqMax            = max(Freqs) ;
        Summary(index).NrOfAPsMax         = max(NrofAPs) ; 
        Summary(index).FreqTrSwp          = FreqTrSwp ;
        Summary(index).NrOfAPsTrSwp       = NrOfAPsTrSwp ; 
        Summary(index).FrqChngStimInt     = FrqChngStimInt ;
        Summary(index).NrofRBAPs          = sum(NrofRBAPs) ;
        Summary(index).NrofRBAPsM         = NrofRBAPsM ;
        Summary(index).Sag                = sweep(sagswp,1).epoch(step).sag / PkDeflect(sagswp,1) ;
        Summary(index).VmatSag            = MinVmResponse(sagswp,1) ;
        Summary(index).TauM               = nanmean(taus(taus~=0)) ;
        Summary(index).TauSD              = nanstd(taus(taus~=0)) ;
        Summary(index).OnsetFrstAP        = sweep(frstspikeswp).ap(1).thresh_time - (sum(second({sweep(frstspikeswp).epoch(1:step-1).timespan}))*1000) ; 
        Summary(index).ThreshFrstAP       = sweep(frstspikeswp).ap(1).thresh ; 
        Summary(index).FAPbasetothresh    = sweep(frstspikeswp).ap(1).thresh-sweep(frstspikeswp).vmbase ; 
        Summary(index).AmpFAPthresh       = sweep(frstspikeswp).ap(1).amp ;
        Summary(index).FAPpeaktoahp       = sweep(frstspikeswp).ap(1).ahp_time - sweep(frstspikeswp).ap(1).peak_time ;
        Summary(index).HalfWFrstAP        = sweep(frstspikeswp).ap(1).halfwidth ; 
        Summary(index).AHPFrstAP          = sweep(frstspikeswp).ap(1).relahp ; 
        Summary(index).UpStrkFrstAP       = sweep(frstspikeswp).ap(1).maxdvdt ;
        Summary(index).DwnStrkFrstAP      = sweep(frstspikeswp).ap(1).mindvdt ;
        Summary(index).UpDwnStrkRatio     = abs(sweep(frstspikeswp).ap(1).maxdvdt) / abs(sweep(frstspikeswp).ap(1).mindvdt) ;
        Summary(index).OnsetTSFAP         = OnsetTSFAP ;  
        Summary(index).TSbasetothreshM    = mean(TSbasetothresh) ; 
        Summary(index).TSbasetothreshSD   = std(TSbasetothresh) ; 
        Summary(index).AmpTSthreshM       = mean(AmpsTSthresh) ; 
        Summary(index).AmpTSthreshSD      = std(AmpsTSthresh) ; 
        Summary(index).TSpeaktoahpM       = mean(TSpeaktoahp) ; 
        Summary(index).TSpeaktoahpSD      = std(TSpeaktoahp) ; 
        Summary(index).HalfWTrSwpM        = mean(HWsTS) ; 
        Summary(index).HalfWTrSwpSD       = std(HWsTS) ; 
        Summary(index).AHPTrSwpM          = mean(AHPsTS) ; 
        Summary(index).AHPTrSwpSD         = std(AHPsTS) ;
        Summary(index).ISITrSwpM          = mean(ISIsTS(ISIsTS~=0)) ;
        Summary(index).ISITrSwpSD         = std(ISIsTS(ISIsTS~=0)) ;
        Summary(index).ISITrSwpCV         = (std(ISIsTS(ISIsTS~=0)) / mean(ISIsTS(ISIsTS~=0))) ; %coefficient of variation
        Summary(index).AdaptIndexTS       = AdaptIdx ;
        Summary(index).AmpAccomTS         = AmpAccom ;
        Summary(index).HWAccomTS          = HWAccom ;
        Summary(index).ISIRatio1toAll     = ISIRatio1toAll ;

        %clear variables assigned in "sweep" For loop
        clearvars -except abf Summary i basedir savename abfs aps channels ins epochs sweeps index
        index = index + 1 ;
    end
end
%% save
save(fullfile(basedir, savename), 'Summary') ;
clearvars -except Summary i










