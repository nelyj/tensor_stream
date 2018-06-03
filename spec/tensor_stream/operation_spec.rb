require "spec_helper"
require 'benchmark'

RSpec.describe TensorStream::Operation do

  let(:tf) { TensorStream } # allow calls to look like tensorflow
  let(:sess) { tf.session }

  context ".zeros_like" do
    it "Creates a tensor with all elements set to zero." do
      tensor = tf.constant([[1, 2, 3], [4, 5, 6]])
      z = tf.zeros_like(tensor)
      expect(z.eval).to eq([[0, 0, 0], [0, 0, 0]])
    end
  end

  context ".concat" do
    it "Concatenates tensors along one dimension." do
      t1 = [[1, 2, 3], [4, 5, 6]]
      t2 = [[7, 8, 9], [10, 11, 12]]
      expect(tf.concat([t1, t2], 0).eval).to eq([[1, 2, 3], [4, 5, 6], [7, 8, 9], [10, 11, 12]])
      expect(tf.concat([t1, t2], 1).eval).to eq([[1, 2, 3, 7, 8, 9], [4, 5, 6, 10, 11, 12]])
    end

    it "negative axis" do
      t1 = [[[1, 2], [2, 3]], [[4, 4], [5, 3]]]
      t2 = [[[7, 4], [8, 4]], [[2, 10], [15, 11]]]
      expect(tf.concat([t1, t2], -1).eval).to eq(
      [[[ 1,  2,  7,  4],
        [ 2,  3,  8,  4]],
       [[ 4,  4,  2, 10],
        [ 5,  3, 15, 11]]])
    end
  end

  context ".reshape" do
    it "Reshapes a tensor." do
      t = [1, 2, 3, 4, 5, 6, 7, 8, 9]
      expect(tf.reshape(t, [3, 3]).eval).to eq(
        [[1, 2, 3],
        [4, 5, 6],
        [7, 8, 9]])

      t = [[[1, 1], [2, 2]],
           [[3, 3], [4, 4]]]

      expect(tf.reshape(t, [2, 4]).eval).to eq([[1, 1, 2, 2],
        [3, 3, 4, 4]])
    end

    it "reshape to scalar" do
      t = [7]
      expect(tf.reshape(t, []).eval).to eq(7)

      t = 7
      expect(tf.reshape(t, []).eval).to eq(7)
    end

    it "flattens a tensor" do
      t = [[[1, 1, 1],
            [2, 2, 2]],
          [[3, 3, 3],
          [4, 4, 4]],
          [[5, 5, 5],
          [6, 6, 6]]]
      expect(tf.shape(t).eval).to eq([3, 2, 3])
      expect(tf.reshape(t, [-1]).eval).to eq([1, 1, 1, 2, 2, 2, 3, 3, 3, 4, 4, 4, 5, 5, 5, 6, 6, 6])
      expect(tf.reshape(t, [2, -1]).eval).to eq([[1, 1, 1, 2, 2, 2, 3, 3, 3],
                         [4, 4, 4, 5, 5, 5, 6, 6, 6]])
    end

    it "should fail if dimensions do not match" do
      t = [[[1, 1, 1],
            [2, 2, 2]],
          [[3, 3, 3],
          [4, 4, 4]],
          [[5, 5, 5],
          [6, 6, 6]]]
      expect {
        tf.reshape(t,[3,2,2]).eval
      }.to raise_exception

    end

    it "inference" do
      t = [[[1, 1, 1],
            [2, 2, 2]],
            [[3, 3, 3],
            [4, 4, 4]],
            [[5, 5, 5],
            [6, 6, 6]]]

      expect(tf.reshape(t, [-1, 9]).eval).to eq([[1, 1, 1, 2, 2, 2, 3, 3, 3],
        [4, 4, 4, 5, 5, 5, 6, 6, 6]])
      
      expect(tf.reshape(t, [ 2, -1, 3]).eval).to eq(
        [[[1, 1, 1],
          [2, 2, 2],
          [3, 3, 3]],
          [[4, 4, 4],
          [5, 5, 5],
          [6, 6, 6]]])
    end
  end

  context ".glorot_uniform_initializer" do
    it "initializes variables using the Glorot uniform initializer" do
      tf.set_random_seed(1234)
      u = tf.get_variable('v', shape: [], dtype: :float32)
      v = tf.get_variable('v1', shape: [5], dtype: :float32)
      y = tf.get_variable('v2', shape: [3, 3], dtype: :float32)
      sess.run(tf.global_variables_initializer)
      expect(tr(sess.run(u))).to eq(-1.0686)
      expect(tr(sess.run(v))).to eq([0.2442, -0.1245, 0.5707, 0.56, -0.4548])
      expect(tr(sess.run(y))).to eq([
        [-0.4471, 0.6037, 0.9163],
        [0.7519, -0.2844, 0.002],
        [0.3669, 0.4254, -0.2595]])
    end
  end

  # Outputs random values from a uniform distribution.
  # The generated values follow a uniform distribution in the range [minval, maxval). The lower bound minval is included in the range, while the upper bound maxval is excluded.
  # For floats, the default range is [0, 1). For ints, at least maxval must be specified explicitly.
  # In the integer case, the random integers are slightly biased unless maxval - minval is an exact power of two. The bias is small for values of maxval - minval significantly smaller than the range of the output (either 2**32 or 2**64).
  context ".random_uniform" do
    before do
      tf.set_random_seed(1234)
      @sess = tf.session
    end
  
    [
      [[],     0.1915194503788923,       0.3830389007577846         ],
      [[1],   [0.1915194503788923],      [0.3830389007577846]         ],
      [[2,3], [[0.1915194503788923, 0.6221087710398319, 0.4377277390071145], [0.7853585837137692, 0.7799758081188035, 0.2725926052826416]],  [[0.3830389007577846, 1.2442175420796637, 0.875455478014229], [1.5707171674275384, 1.559951616237607, 0.5451852105652832]] ]
    ].each do |shape, expected, range_expected|
      describe "shape #{shape}" do
        it "generates random uniform values" do
          expect(@sess.run(tf.random_uniform(shape))).to eq(expected)
        end

        specify "with ranges" do
          expect(@sess.run(tf.random_uniform(shape, minval: 0, maxval: 2))).to eq(range_expected)
        end
      end
    end

    context "shape (3,)" do
      it "Creates an operation to generate a random set of values of the given shape" do
        vec = tf.random_uniform([3])
        expect(@sess.run(vec)).to eq([0.1915194503788923, 0.6221087710398319, 0.4377277390071145])

        #evaluating again generates new values
        expect(@sess.run(vec)).to eq([0.7853585837137692, 0.7799758081188035, 0.2725926052826416])
      end
    end

    context "shape (2, 2)" do
      it "Creates an operation to generate a random set of values of the given shape" do
        vec = tf.random_uniform([2,2])
        expect(@sess.run(vec)).to eq([[0.1915194503788923, 0.6221087710398319], [0.4377277390071145, 0.7853585837137692]])

        #evaluating again generates new values
        expect(@sess.run(vec)).to eq([[0.7799758081188035, 0.2725926052826416], [0.2764642551430967, 0.8018721775350193]])
      end
    end
  end

  context ".set_random_seed" do
    it "sets the graph level seed" do
      tf.set_random_seed(1000)
      a = tf.random_uniform([1])
      sess = tf.session
      expect(sess.run(a)).to eq([0.6535895854646095])
      expect(sess.run(a)).to eq([0.11500694312440574])

      sess2 = tf.session
      expect(sess2.run(a)).to eq([0.6535895854646095])
      expect(sess2.run(a)).to eq([0.11500694312440574])
    end
  end

  context ".pad" do
    it "pads a tensor, rank 1" do
      t = tf.constant([1, 2, 3])
      paddings = tf.constant([[1,1]])
      expect(tf.pad(t, paddings).eval).to eq([0, 1, 2, 3, 0])
    end

    it "pads a tensor, rank 2" do
      t = tf.constant([[1, 2, 3], [4, 5, 6]])
      paddings = tf.constant([[1, 1], [2, 2]])

      expect(tf.pad(t, paddings, mode: "CONSTANT").eval).to eq(
        [[0, 0, 0, 0, 0, 0, 0],
         [0, 0, 1, 2, 3, 0, 0],
         [0, 0, 4, 5, 6, 0, 0],
         [0, 0, 0, 0, 0, 0, 0]]
      )

      paddings_2 = tf.constant([[0, 1], [0, 2]])
      expect(tf.pad(t, paddings_2, mode: "CONSTANT").eval).to eq(
        [
         [1, 2, 3, 0, 0],
         [4, 5, 6, 0, 0],
         [0, 0, 0, 0, 0]
        ]
      )

      paddings_3 = tf.constant([[1, 0], [2, 0]])
      expect(tf.pad(t, paddings_3, mode: "CONSTANT").eval).to eq(
        [[0, 0, 0, 0, 0],
         [0, 0, 1, 2, 3],
         [0, 0, 4, 5, 6]]
      )
    end
  end

  context ".derivative" do
    it "Creates a derivative graph for a computation" do
      x = tf.placeholder(TensorStream::Types.float32)
      p = tf.pow(x, 3) 

      derivative_function = TensorStream::MathGradients.derivative(p, x)
      expect(p.eval(feed_dict: { x => 2})).to eq(8)
      expect(derivative_function.eval(feed_dict: { x => 2})).to eq(12)
  
      # f(x) = (sin x) ^ 3
      # dx = 3(sin x)^2 * cos x
      y = tf.sin(x) ** 3
      derivative_function_y = TensorStream::MathGradients.derivative(y, x)
      expect(derivative_function_y.eval(feed_dict: { x => 1 })).to eq(1.147721101851439)
    end
  end

  context ".eye" do
    it "creates an identity matrix" do
      tf.program do |tf|
        e = tf.eye(2)
        expect(e.eval).to eq([[1.0, 0.0],[0.0, 1.0]])

        e = tf.eye(3)
        expect(e.eval).to eq([[1.0, 0.0, 0.0], [0.0, 1.0, 0.0], [0.0, 0.0, 1.0]])

        e = tf.eye(3, num_columns: 2)
        expect(e.eval).to eq([[1.0, 0.0], [0.0, 1.0], [0.0, 0.0]])
      end
    end

    specify "using in matrix multiplication" do
      a = tf.constant([[1.0, 2.0, 3.0], [1.0, 2.0, 3.0]])
      b = tf.constant([[0.1, 0.1], [0.1, 0.1], [0.2, 0.2]])
      m = tf.matmul(a, b)
      expect(m.eval).to eq([[0.9000000000000001, 0.9000000000000001], [0.9000000000000001, 0.9000000000000001]])

      g = tf.gradients(m, [a])
      expect(g.eval).to eq([[[0.2, 0.2, 0.4], [0.2, 0.2, 0.4]]])

      d_wra = tf.matmul(tf.eye(a.shape[0]), b, transpose_b: true)
      expect(d_wra.eval).to eq([[0.1, 0.1, 0.2], [0.1, 0.1, 0.2]])
    end
  end

  context ".gradients" do
    it "Constructs symbolic derivatives of sum of ys w.r.t. x in xs." do
      a = tf.constant(0.0)
      b = a * 2
      g = tf.gradients(a + b, [a, b], stop_gradients: [a, b])
      h = tf.gradients(a + b, [a, b])

      expect(g.eval).to eq([1.0, 1.0])
      expect(h.eval).to eq([3.0, 1.0])
    end

    it "using stop gradients" do
      a = tf.stop_gradient(tf.constant(0.0))
      b = tf.stop_gradient(a * 2)
      h = tf.gradients(a + b, [a, b])
      expect((a+b).eval).to eq(0)
      expect((a+b).to_math).to eq("\n (\n  0.0 + \n  \n   (\n    0.0 * 2.0))")
      expect(h.eval).to eq([1.0, 1.0])
    end

    it "computes gradient of sin" do
      var = tf.constant(1.0) # Must be a tf.float32 or tf.float64 variable.
      loss = tf.sin(var) # some_function_of() returns a `Tensor`.
      var_grad = tf.gradients(loss, [var])[0]

      expect(var_grad.eval).to eq(0.5403023058681398)
    end
  end

  context ".cond" do
    it "returns a specific tensor function depending on the value of the predicate"  do
      x = tf.constant(2.0)
      y = tf.constant(3.0)
      z = tf.multiply(x, y)

      result = tf.cond(x < y, tf.add(x, z), tf.square(y))
      result2 = tf.cond(x > y, -> { tf.add(x, z) }, -> { tf.square(y) })
      expect(result.eval).to eq(8.0)
      expect(result2.eval).to eq(9.0)
    end

    it "supports gradients" do
      x = tf.constant(2.0)
      y = tf.constant(3.0)
      z = tf.multiply(x, y)

      result = tf.cond(x < y, tf.add(x, z), tf.square(y))
      result2 = tf.cond(x > y, tf.add(x, z), tf.square(y))

      grad1 = tf.gradients(result, [x, y])
      grad2 = tf.gradients(result2, [x, y])

      expect(grad1.eval).to eq([4.0, 2.0])
      expect(grad2.eval).to eq([0.0, 6.0])
    end
  end

  context ".reduce_mean" do
    it "Computes the mean of elements across dimensions of a tensor" do
      x = tf.constant([[1.0, 1.0], [2.0, 2.0]])
      expect(tf.reduce_mean(x).eval).to eq(1.5)
      expect(tf.reduce_mean(x, 0).eval).to eq([1.5, 1.5])
      expect(tf.reduce_mean(x, 1).eval).to eq([1.0, 2.0])

      y = tf.constant([[1.0, 1.0, 1.0], [2.0, 2.0, 3.0], [1.5, -1.1, 1.1]])
      expect(tr(tf.reduce_mean(y).eval)).to eq(1.2778)
      expect(tr(tf.reduce_mean(y, 0).eval)).to eq([1.5, 0.6333, 1.7])
      expect(tr(tf.reduce_mean(y, 1).eval)).to eq([1.0, 2.3333, 0.5])
    end

    it ".computes for the gradient" do
      x = tf.constant([[1.0, 1.0], [2.0, 2.0]])
      f = tf.reduce_mean(x)
      g = tf.gradients(f, [x])
      expect(g.eval).to eq([[[0.25, 0.25], [0.25, 0.25]]])
    end
  end

  context ".tile" do
    it "Constructs a tensor by tiling a given tensor." do
      a = tf.constant([[1, 2, 3, 4], [1, 2, 3, 4]])
      expect(tf.tile(a,[1, 0]).eval).to eq([])
      expect(tf.tile(a,[0, 1]).eval).to eq([])
      expect(tf.tile(a,[1, 1]).eval).to eq([[1, 2, 3, 4], [1, 2, 3, 4]])
      expect(tf.tile(a,[2, 1]).eval).to eq([[1, 2, 3, 4], [1, 2, 3, 4], [1, 2, 3, 4], [1, 2, 3, 4]])
      expect(tf.tile(a,[1, 2]).eval).to eq([[1, 2, 3, 4, 1, 2, 3, 4], [1, 2, 3, 4, 1, 2, 3, 4]])
    end
  end

  context "combination of functions" do
    it "add two operation together" do
      y = tf.sin(1.0) + tf.sin(2.0)
      expect(y.eval).to eq(1.7507684116335782)
    end
  end
end