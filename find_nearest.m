function [near_scalar, index] = find_nearest(scalar,list)
%function [near_scalar, index] = find_nearest(scalar,list);
% Finds the nearest value in a list to the scalar given
% Returns the nearest scalar, and the index to it in list
% such that list(index) == near_scalar

% List is assumed to be a vector.  Otherwise
% list = reshape(list, 1, [])

% This assumes that list is sorted and ascending.  Otherwise, 
% sort(list)
% But doing that here in the program would cause the return 
% index to no longer be valid.  

diff = abs(list - scalar);
[~, index_a] = min(diff);
index = index_a(1);  % We do this so if we are between two values, or have
                     % multiple equal values, we will pick the first
near_scalar = list(index);