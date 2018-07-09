function [ covdata ] = get_single_model_coverage( sys )
%GET_SINGLE_MODEL_COVERAGE Summary of this function goes here
%   Potentially to be called from a parfor loop
    covdata = get_coverage(sys);
            
end

function ret = get_coverage(sys)
    % ret contains result for a single model
    ret = struct(...
        'opens', false,...
        'timedout', false,...
        'simdur', [],...
        'exception', false,...
        'exception_msg', [],...
        'sys', sys,...
        'blocks', [],...
        'numzerocov', [],...
        'duration', []);
    
    l = logging.getLogger('singlemodel');

    num_zero_cov = 0; % blocks with zero coverage
    
    % Does it open?
    
    try
        h = load_system(sys);
        if covcfg.OPEN_MODELS
            open_system(sys);
        end
        ret.opens = true;
    catch e
        ret.exception = true;
        ret.exception_msg = e.identifier;
        getReport(e)
        return;
    end

    % Does it run within timeout limit?
    
    try
        time_start = tic;
        
        simob = utility.TimedSim(sys, covcfg.SIMULATION_TIMEOUT, l);
        ret.timedout = simob.start();

        if ret.timedout
            % Close
            covexp.sys_close(sys);
            return;
        end
        
        ret.simdur = toc(time_start);
        
    catch e
        ret.exception = true;
        ret.exception_msg = e.identifier;
     
        getReport(e)
        
        % Close
        covexp.sys_close(sys);
    end
    
    
    % Now collect coverage!
    
    try
        time_start = tic;
        
        testObj  = cvtest(h);
        data = cvsim(testObj);

        blocks = get_all_blocks(h);

        all_blocks = struct;

        for i=1:numel(blocks)
            cur_blk = blocks(i);

            cur_blk_name = getfullname(cur_blk);

            cov = executioninfo(data, cur_blk);
            percent_cov = [];

            if ~ isempty(cov)
                percent_cov = 100 * cov(1) / cov(2);

                if percent_cov == 0
                    num_zero_cov = num_zero_cov + 1;
                end
            end


            all_blocks(i).fullname = cur_blk_name;
            all_blocks(i).percentcov = percent_cov;
        end
        
        ret.duration = toc(time_start);

        ret.blocks = all_blocks;
        ret.numzerocov = num_zero_cov;
        
        % Close
        covexp.sys_close(sys);
    catch e
        ret.exception = true;
        ret.exception_msg = e.identifier;
        
        getReport(e)
        
        % Close
        covexp.sys_close(sys);
    end

end

function ret = get_all_blocks(sys)
    ret = find_system(sys, 'LookUnderMasks', 'all');
%     ret = find_system(sys, 'LookUnderMasks', 'all', 'Variants', 'AllVariants');    
end