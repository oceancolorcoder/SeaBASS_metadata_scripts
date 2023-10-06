
wipe

senAz = [180 269 350 10 190];
% solAz = [90  90   90 90 90];
% goal = [90   179 -100 -80 100];
% solAz = [270  270 270 270 270];
% goal = [-90   -1  80 100 -80];
solAz = 359;
goal = [-179 -90 -9  11 -169];

relAz = senAz - solAz;

relAz(relAz>180) = relAz(relAz>180) - 360;
relAz(relAz<-180) = relAz(relAz<-180) + 360;

disp(relAz - goal)