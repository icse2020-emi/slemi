classdef BaseTester < handle
    %BASETESTER Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        %%
        models;
        locs;               % Location of the models
        configs;
        
        r;                  % report: difftest.TesterReport
        
        l = logging.getLogger('BaseTester');
        
        execution_decs;     % Execution decorators
    end
    
    methods
        function obj = BaseTester(models, model_locs, configs, exec_decs)
            %%
            obj.r = difftest.TesterReport();
            
            obj.models = models;
            obj.locs = model_locs;
            obj.configs = configs;
            
            obj.r.executions = utility.cell();
            
            
            if nargin == 3
                exec_decs = difftest.cfg.EXECUTOR;
            end
            
            obj.execution_decs = exec_decs;
        end
        
        function go(obj, compare, comparator)
            %%
            
            if nargin == 1
                compare = false;
            end
            
            if nargin <= 2
                comparator = difftest.cfg.COMPARATOR;
            end
            
            obj.init_exec_reports();
            obj.execute_all();
            obj.r.aggregate_before_comp();
            
            obj.run_comparison(compare, comparator);
            
            obj.cleanup();       
        end
        
        
        function run_comparison(obj, compare, comparator)
            %%
            if ~ compare
                return;
            end
            
            cf = comparator(obj.r);
            cf.go();
        end
      
        function init_exec_reports(obj)
            %%
            for i=1:numel(obj.models)
                
                all_configs = obj.cartesian_helper(1);
                
                for j = 1:all_configs.len
                    cur = all_configs.get(j);
                    temp = cur.create_copy([]);
                    
                    temp.sys = obj.models{i};
                    temp.loc = obj.locs{i};
                    
                    obj.r.executions.add(temp);
                end
                
            end
        end
        
        
        function ret = cartesian_helper(obj, pos)
            %%
            ret = utility.cell;
            
            % Base Case
            if pos > numel(obj.configs)
                ret.add(difftest.ExecutionReport());
                return;
            end
            
            children = obj.cartesian_helper(pos+1);
            
            for i=1:numel(obj.configs{pos})
                for j = 1:children.len
                    child = children.get(j);
                    ret.add(child.create_copy(obj.configs{pos}{i}));
                end
            end
        end
        
        function execute_all(obj)
            %%
            seen = struct;
            
            for i = 1: obj.r.executions.len
                cur = obj.r.executions.get(i);
                
                reuse_pre_exec_copy = isfield(seen, cur.sys);
                
                executor = difftest.BaseExecutor(cur, reuse_pre_exec_copy, obj.execution_decs);
                executor.go();
                executor.cleanup();
                
                if cur.is_ok(difftest.ExecStatus.PreExec)
                    seen.(cur.sys) = true;
                end
                
                if ~ cur.is_ok()
                    obj.l.error('Error config # %d. Last successful step: %s \nSkipping %d remaining configs.', i, cur.last_ok, (obj.r.executions.len - i));
                    return;
                end
                
            end
        end
        
        function cleanup(obj)
            %% Delete pre-exec model
            if difftest.cfg.DELETE_PRE_EXEC_MODELS
                obj.l.info('Deleting pre-exec files...');
                for i=1:obj.r.executions.len
                    cur = obj.r.executions.get(i);
                    if ~ isempty( cur.preexec_file)
                        try
                            delete(cur.preexec_file);
                        catch me
                            obj.l.warn('Pre exec file deletion error');
                            disp(me);
                        end
                    end
                end
            end
        end
        
    end
end

