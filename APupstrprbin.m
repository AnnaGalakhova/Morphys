%% 
%%how to load specific stimsets of the file - stimsets containing APs (and
%%supposed to contain APs)

fn = '/Users/annagalakhova/PhD INF CNCR VU/DATA/L1_nAChRs currents/Human_ephys/done/H21.29.201.11.11.01.nwb'

nwb = NWBfile(fn,[{'X2LP_Search'} {'teps'}])

%getting the sweeps I need
swps = nwb.getstimset.getnwbchannel.getsweep;
%analysis of the sweeps
swps = swps.analysesweep;
% getting th eAPs from the sweeps which have them 
APs = swps.getap;
%%getting the frequency of every AP
inst_freqs = [APs.freq];
% dividing the APS into the bins to get the ones we need 
binedges = [0,0.00001, 10, 20, 30, 40, 500];

bins = discretize(inst_freqs, binedges);
binlabels = {'FirstAP', 's0to10 Hz', 's10to20 Hz','s20to30 Hz' 's30to40 Hz', 's40toINF Hz'};

upstrokes = [APs.maxdvdt];

scatter(categorical(binlabels(bins)), upstrokes) 

%choose specific APs and get data per bin
mean_binned_upstrokes=NaN(1, numel(binlabels));
median_binned_upstrokes=NaN(1, numel(binlabels));
for i=1:numel(binlabels)
    mean_binned_upstrokes(i) = nanmean(upstrokes(bins==i) )  ; 
    median_binned_upstrokes(i) = nanmedian(upstrokes(bins==i) )  ;
end

boxplot(upstrokes, bins)
hold on
mean_binned_upstrokes
median_binned_upstrokes
plot(swps)
scatter(categorical(binlabels(bins)), upstrokes) 