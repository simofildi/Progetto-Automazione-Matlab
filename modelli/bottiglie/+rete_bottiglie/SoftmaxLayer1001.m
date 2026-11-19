classdef SoftmaxLayer1001 < nnet.layer.Layer & nnet.layer.Formattable
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
        function this = SoftmaxLayer1001(name)
            this.Name = name;
            this.OutputNames = {'x_model_10_m_m_0__10'};
        end

        function [x_model_10_m_m_0__10] = predict(this, x_model_10_m_m_0_a_6)
            if isdlarray(x_model_10_m_m_0_a_6)
                x_model_10_m_m_0_a_6 = stripdims(x_model_10_m_m_0_a_6);
            end
            x_model_10_m_m_0_a_6NumDims = 4;
            x_model_10_m_m_0_a_6 = rete_bottiglie.ops.permuteInputVar(x_model_10_m_m_0_a_6, ['as-is'], 0);

            [x_model_10_m_m_0__10, x_model_10_m_m_0__10NumDims] = SoftmaxGraph1002(this, x_model_10_m_m_0_a_6, x_model_10_m_m_0_a_6NumDims, false);
            x_model_10_m_m_0__10 = rete_bottiglie.ops.permuteOutputVar(x_model_10_m_m_0__10, ['as-is'], 0);

            x_model_10_m_m_0__10 = dlarray(single(x_model_10_m_m_0__10), repmat('U', 1, max(2, x_model_10_m_m_0__10NumDims)));
        end

        function [x_model_10_m_m_0__10] = forward(this, x_model_10_m_m_0_a_6)
            if isdlarray(x_model_10_m_m_0_a_6)
                x_model_10_m_m_0_a_6 = stripdims(x_model_10_m_m_0_a_6);
            end
            x_model_10_m_m_0_a_6NumDims = 4;
            x_model_10_m_m_0_a_6 = rete_bottiglie.ops.permuteInputVar(x_model_10_m_m_0_a_6, ['as-is'], 0);

            [x_model_10_m_m_0__10, x_model_10_m_m_0__10NumDims] = SoftmaxGraph1002(this, x_model_10_m_m_0_a_6, x_model_10_m_m_0_a_6NumDims, true);
            x_model_10_m_m_0__10 = rete_bottiglie.ops.permuteOutputVar(x_model_10_m_m_0__10, ['as-is'], 0);

            x_model_10_m_m_0__10 = dlarray(single(x_model_10_m_m_0__10), repmat('U', 1, max(2, x_model_10_m_m_0__10NumDims)));
        end

        function [x_model_10_m_m_0__10, x_model_10_m_m_0__10NumDims1003] = SoftmaxGraph1002(this, x_model_10_m_m_0_a_6, x_model_10_m_m_0_a_6NumDims, Training)

            % Execute the operators:
            % Softmax:
            [x_model_10_m_m_0__10, x_model_10_m_m_0__10NumDims] = rete_bottiglie.ops.onnxSoftmax13(x_model_10_m_m_0_a_6, -1, x_model_10_m_m_0_a_6NumDims);

            % Set graph output arguments
            x_model_10_m_m_0__10NumDims1003 = x_model_10_m_m_0__10NumDims;

        end

    end

end