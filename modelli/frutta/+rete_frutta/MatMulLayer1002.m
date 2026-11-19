classdef MatMulLayer1002 < nnet.layer.Layer & nnet.layer.Formattable
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
        function this = MatMulLayer1002(name)
            this.Name = name;
            this.NumInputs = 2;
            this.OutputNames = {'x_model_10_m_m_0_a_4'};
        end

        function [x_model_10_m_m_0_a_4] = predict(this, x_model_10_m_m_0__13, x_model_10_m_m_0__14)
            if isdlarray(x_model_10_m_m_0__13)
                x_model_10_m_m_0__13 = stripdims(x_model_10_m_m_0__13);
            end
            if isdlarray(x_model_10_m_m_0__14)
                x_model_10_m_m_0__14 = stripdims(x_model_10_m_m_0__14);
            end
            x_model_10_m_m_0__13NumDims = 4;
            x_model_10_m_m_0__14NumDims = 4;
            x_model_10_m_m_0__13 = rete_frutta.ops.permuteInputVar(x_model_10_m_m_0__13, ['as-is'], 0);
            x_model_10_m_m_0__14 = rete_frutta.ops.permuteInputVar(x_model_10_m_m_0__14, ['as-is'], 0);

            [x_model_10_m_m_0_a_4, x_model_10_m_m_0_a_4NumDims] = MatMulGraph1004(this, x_model_10_m_m_0__13, x_model_10_m_m_0__14, x_model_10_m_m_0__13NumDims, x_model_10_m_m_0__14NumDims, false);
            x_model_10_m_m_0_a_4 = rete_frutta.ops.permuteOutputVar(x_model_10_m_m_0_a_4, ['as-is'], 0);

            x_model_10_m_m_0_a_4 = dlarray(single(x_model_10_m_m_0_a_4), repmat('U', 1, max(2, x_model_10_m_m_0_a_4NumDims)));
        end

        function [x_model_10_m_m_0_a_4] = forward(this, x_model_10_m_m_0__13, x_model_10_m_m_0__14)
            if isdlarray(x_model_10_m_m_0__13)
                x_model_10_m_m_0__13 = stripdims(x_model_10_m_m_0__13);
            end
            if isdlarray(x_model_10_m_m_0__14)
                x_model_10_m_m_0__14 = stripdims(x_model_10_m_m_0__14);
            end
            x_model_10_m_m_0__13NumDims = 4;
            x_model_10_m_m_0__14NumDims = 4;
            x_model_10_m_m_0__13 = rete_frutta.ops.permuteInputVar(x_model_10_m_m_0__13, ['as-is'], 0);
            x_model_10_m_m_0__14 = rete_frutta.ops.permuteInputVar(x_model_10_m_m_0__14, ['as-is'], 0);

            [x_model_10_m_m_0_a_4, x_model_10_m_m_0_a_4NumDims] = MatMulGraph1004(this, x_model_10_m_m_0__13, x_model_10_m_m_0__14, x_model_10_m_m_0__13NumDims, x_model_10_m_m_0__14NumDims, true);
            x_model_10_m_m_0_a_4 = rete_frutta.ops.permuteOutputVar(x_model_10_m_m_0_a_4, ['as-is'], 0);

            x_model_10_m_m_0_a_4 = dlarray(single(x_model_10_m_m_0_a_4), repmat('U', 1, max(2, x_model_10_m_m_0_a_4NumDims)));
        end

        function [x_model_10_m_m_0_a_4, x_model_10_m_m_0_a_4NumDims1005] = MatMulGraph1004(this, x_model_10_m_m_0__13, x_model_10_m_m_0__14, x_model_10_m_m_0__13NumDims, x_model_10_m_m_0__14NumDims, Training)

            % Execute the operators:
            % MatMul:
            [x_model_10_m_m_0_a_4, x_model_10_m_m_0_a_4NumDims] = rete_frutta.ops.onnxMatMul(x_model_10_m_m_0__13, x_model_10_m_m_0__14, x_model_10_m_m_0__13NumDims, x_model_10_m_m_0__14NumDims);

            % Set graph output arguments
            x_model_10_m_m_0_a_4NumDims1005 = x_model_10_m_m_0_a_4NumDims;

        end

    end

end