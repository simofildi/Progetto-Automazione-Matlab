classdef MatMulLayer1000 < nnet.layer.Layer & nnet.layer.Formattable
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
        function this = MatMulLayer1000(name)
            this.Name = name;
            this.NumInputs = 2;
            this.OutputNames = {'x_model_10_m_m_0_a_5'};
        end

        function [x_model_10_m_m_0_a_5] = predict(this, x_model_10_m_m_0__15, x_model_10_m_m_0__12)
            if isdlarray(x_model_10_m_m_0__15)
                x_model_10_m_m_0__15 = stripdims(x_model_10_m_m_0__15);
            end
            if isdlarray(x_model_10_m_m_0__12)
                x_model_10_m_m_0__12 = stripdims(x_model_10_m_m_0__12);
            end
            x_model_10_m_m_0__15NumDims = 4;
            x_model_10_m_m_0__12NumDims = 4;
            x_model_10_m_m_0__15 = rete_oggetti.ops.permuteInputVar(x_model_10_m_m_0__15, ['as-is'], 0);
            x_model_10_m_m_0__12 = rete_oggetti.ops.permuteInputVar(x_model_10_m_m_0__12, ['as-is'], 0);

            [x_model_10_m_m_0_a_5, x_model_10_m_m_0_a_5NumDims] = MatMulGraph1000(this, x_model_10_m_m_0__15, x_model_10_m_m_0__12, x_model_10_m_m_0__15NumDims, x_model_10_m_m_0__12NumDims, false);
            x_model_10_m_m_0_a_5 = rete_oggetti.ops.permuteOutputVar(x_model_10_m_m_0_a_5, ['as-is'], 0);

            x_model_10_m_m_0_a_5 = dlarray(single(x_model_10_m_m_0_a_5), repmat('U', 1, max(2, x_model_10_m_m_0_a_5NumDims)));
        end

        function [x_model_10_m_m_0_a_5] = forward(this, x_model_10_m_m_0__15, x_model_10_m_m_0__12)
            if isdlarray(x_model_10_m_m_0__15)
                x_model_10_m_m_0__15 = stripdims(x_model_10_m_m_0__15);
            end
            if isdlarray(x_model_10_m_m_0__12)
                x_model_10_m_m_0__12 = stripdims(x_model_10_m_m_0__12);
            end
            x_model_10_m_m_0__15NumDims = 4;
            x_model_10_m_m_0__12NumDims = 4;
            x_model_10_m_m_0__15 = rete_oggetti.ops.permuteInputVar(x_model_10_m_m_0__15, ['as-is'], 0);
            x_model_10_m_m_0__12 = rete_oggetti.ops.permuteInputVar(x_model_10_m_m_0__12, ['as-is'], 0);

            [x_model_10_m_m_0_a_5, x_model_10_m_m_0_a_5NumDims] = MatMulGraph1000(this, x_model_10_m_m_0__15, x_model_10_m_m_0__12, x_model_10_m_m_0__15NumDims, x_model_10_m_m_0__12NumDims, true);
            x_model_10_m_m_0_a_5 = rete_oggetti.ops.permuteOutputVar(x_model_10_m_m_0_a_5, ['as-is'], 0);

            x_model_10_m_m_0_a_5 = dlarray(single(x_model_10_m_m_0_a_5), repmat('U', 1, max(2, x_model_10_m_m_0_a_5NumDims)));
        end

        function [x_model_10_m_m_0_a_5, x_model_10_m_m_0_a_5NumDims1001] = MatMulGraph1000(this, x_model_10_m_m_0__15, x_model_10_m_m_0__12, x_model_10_m_m_0__15NumDims, x_model_10_m_m_0__12NumDims, Training)

            % Execute the operators:
            % MatMul:
            [x_model_10_m_m_0_a_5, x_model_10_m_m_0_a_5NumDims] = rete_oggetti.ops.onnxMatMul(x_model_10_m_m_0__15, x_model_10_m_m_0__12, x_model_10_m_m_0__15NumDims, x_model_10_m_m_0__12NumDims);

            % Set graph output arguments
            x_model_10_m_m_0_a_5NumDims1001 = x_model_10_m_m_0_a_5NumDims;

        end

    end

end