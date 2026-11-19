classdef AddLayer1003 < nnet.layer.Layer & nnet.layer.Formattable
    % A custom layer auto-generated while importing an ONNX network.

    %#ok<*PROPLC>
    %#ok<*NBRAK>
    %#ok<*INUSL>
    %#ok<*VARARG>
    properties (Learnable)
    end

    properties (State)
    end

    properties
        Vars
        NumDims
    end




    methods
        function this = AddLayer1003(name)
            this.Name = name;
            this.NumInputs = 2;
            this.OutputNames = {'x_model_10_m_m_0_att'};
        end

        function [x_model_10_m_m_0_att] = predict(this, x_model_10_m_m_0_a_7, x_model_10_m_m_0__16)
            if isdlarray(x_model_10_m_m_0_a_7)
                x_model_10_m_m_0_a_7 = stripdims(x_model_10_m_m_0_a_7);
            end
            if isdlarray(x_model_10_m_m_0__16)
                x_model_10_m_m_0__16 = stripdims(x_model_10_m_m_0__16);
            end
            x_model_10_m_m_0_a_7NumDims = 4;
            x_model_10_m_m_0__16NumDims = 4;
            x_model_10_m_m_0_a_7 = rete_frutta.ops.permuteInputVar(x_model_10_m_m_0_a_7, ['as-is'], 0);
            x_model_10_m_m_0__16 = rete_frutta.ops.permuteInputVar(x_model_10_m_m_0__16, [4 3 1 2], 4);

            [x_model_10_m_m_0_att, x_model_10_m_m_0_attNumDims] = AddGraph1006(this, x_model_10_m_m_0_a_7, x_model_10_m_m_0__16, x_model_10_m_m_0_a_7NumDims, x_model_10_m_m_0__16NumDims, false);
            x_model_10_m_m_0_att = rete_frutta.ops.permuteOutputVar(x_model_10_m_m_0_att, [3 4 2 1], 4);

            x_model_10_m_m_0_att = dlarray(single(x_model_10_m_m_0_att), 'SSCB');
        end

        function [x_model_10_m_m_0_att] = forward(this, x_model_10_m_m_0_a_7, x_model_10_m_m_0__16)
            if isdlarray(x_model_10_m_m_0_a_7)
                x_model_10_m_m_0_a_7 = stripdims(x_model_10_m_m_0_a_7);
            end
            if isdlarray(x_model_10_m_m_0__16)
                x_model_10_m_m_0__16 = stripdims(x_model_10_m_m_0__16);
            end
            x_model_10_m_m_0_a_7NumDims = 4;
            x_model_10_m_m_0__16NumDims = 4;
            x_model_10_m_m_0_a_7 = rete_frutta.ops.permuteInputVar(x_model_10_m_m_0_a_7, ['as-is'], 0);
            x_model_10_m_m_0__16 = rete_frutta.ops.permuteInputVar(x_model_10_m_m_0__16, [4 3 1 2], 4);

            [x_model_10_m_m_0_att, x_model_10_m_m_0_attNumDims] = AddGraph1006(this, x_model_10_m_m_0_a_7, x_model_10_m_m_0__16, x_model_10_m_m_0_a_7NumDims, x_model_10_m_m_0__16NumDims, true);
            x_model_10_m_m_0_att = rete_frutta.ops.permuteOutputVar(x_model_10_m_m_0_att, [3 4 2 1], 4);

            x_model_10_m_m_0_att = dlarray(single(x_model_10_m_m_0_att), 'SSCB');
        end

        function [x_model_10_m_m_0_att, x_model_10_m_m_0_attNumDims1007] = AddGraph1006(this, x_model_10_m_m_0_a_7, x_model_10_m_m_0__16, x_model_10_m_m_0_a_7NumDims, x_model_10_m_m_0__16NumDims, Training)

            % Execute the operators:
            % Add:
            x_model_10_m_m_0_att = x_model_10_m_m_0_a_7 + x_model_10_m_m_0__16;
            x_model_10_m_m_0_attNumDims = max(x_model_10_m_m_0_a_7NumDims, x_model_10_m_m_0__16NumDims);

            % Set graph output arguments
            x_model_10_m_m_0_attNumDims1007 = x_model_10_m_m_0_attNumDims;

        end

    end

end