RSpec.shared_examples "standard ops evaluator" do
  before(:each) do
    TensorStream::Tensor.reset_counters
    TensorStream::Operation.reset_counters
    tf.reset_default_graph
    sess.clear_session_cache
  end

  it "performs a linear regression" do
    learning_rate = 0.01
    training_epochs = 2
    display_step = 50
    srand(1234)
    train_X = [3.3,4.4,5.5,6.71,6.93,4.168,9.779,6.182,7.59,2.167,
    7.042,10.791,5.313,7.997,5.654,9.27,3.1]
    train_Y = [1.7,2.76,2.09,3.19,1.694,1.573,3.366,2.596,2.53,1.221,
    2.827,3.465,1.65,2.904,2.42,2.94,1.3]

    n_samples = train_X.size

    X = TensorStream.placeholder("float")
    Y = TensorStream.placeholder("float")

    # Set model weights
    W = TensorStream.variable(rand, name: "weight")
    b = TensorStream.variable(rand, name: "bias")

    # Construct a linear model
    pred = X * W + b

    # Mean squared error
    cost = TensorStream.reduce_sum(TensorStream.pow(pred - Y, 2.0)) / ( 2.0 * n_samples)

    optimizer = TensorStream::Train::GradientDescentOptimizer.new(learning_rate).minimize(cost)

    # Initialize the variables (i.e. assign their default value)
    init = TensorStream.global_variables_initializer

    expect {
      sess.run(init)
      (0..training_epochs).each do |epoch|
        train_X.zip(train_Y).each do |x,y|
          sess.run(optimizer, feed_dict: {X => x, Y => y})
        end

        if (epoch+1) % display_step == 0
          c = sess.run(cost, feed_dict: {X => train_X, Y => train_Y})
          puts("Epoch:", '%04d' % (epoch+1), "cost=",  c, \
              "W=", sess.run(W), "b=", sess.run(b))
        end
      end
    }.to_not change(cost.graph.nodes, :size)

    puts("Optimization Finished!")
    training_cost = sess.run(cost, feed_dict: { X => train_X, Y => train_Y})
    puts("Training cost=", training_cost, "W=", sess.run(W), "b=", sess.run(b), '\n')
    expect(tr(W.read_value)).to eq(0.2524)
    expect(tr(b.read_value)).to eq(0.6314)
  end

  context ".zeros_like" do
    it "Creates a tensor with all elements set to zero." do
      tensor = tf.constant([[1, 2, 3], [4, 5, 6]])
      z = tf.zeros_like(tensor)
      expect(sess.run(z)).to eq([[0, 0, 0], [0, 0, 0]])
    end
  end

  context ".concat" do
    it "Concatenates tensors along one dimension." do
      t1 = [[1, 2, 3], [4, 5, 6]]
      t2 = [[7, 8, 9], [10, 11, 12]]
      expect(sess.run(tf.concat([t1, t2], 0))).to eq([[1, 2, 3], [4, 5, 6], [7, 8, 9], [10, 11, 12]])
      expect(sess.run(tf.concat([t1, t2], 1))).to eq([[1, 2, 3, 7, 8, 9], [4, 5, 6, 10, 11, 12]])
    end

    it "negative axis" do
      t1 = [[[1, 2], [2, 3]], [[4, 4], [5, 3]]]
      t2 = [[[7, 4], [8, 4]], [[2, 10], [15, 11]]]
      expect(sess.run(tf.concat([t1, t2], -1))).to eq(
      [[[ 1,  2,  7,  4],
        [ 2,  3,  8,  4]],
       [[ 4,  4,  2, 10],
        [ 5,  3, 15, 11]]])
    end
  end

  context ".reshape" do
    it "Reshapes a tensor." do
      t = [1, 2, 3, 4, 5, 6, 7, 8, 9]
      expect(sess.run(tf.reshape(t, [3, 3]))).to eq(
        [[1, 2, 3],
        [4, 5, 6],
        [7, 8, 9]])

      t = [[[1, 1], [2, 2]],
           [[3, 3], [4, 4]]]

      expect(sess.run(tf.reshape(t, [2, 4]))).to eq([[1, 1, 2, 2],
        [3, 3, 4, 4]])
    end

    it "reshape to scalar" do
      t = [7]
      expect(sess.run(tf.reshape(t, []))).to eq(7)

      t = 7
      expect(sess.run(tf.reshape(t, []))).to eq(7)
    end

    it "flattens a tensor" do
      t = [[[1, 1, 1],
            [2, 2, 2]],
          [[3, 3, 3],
          [4, 4, 4]],
          [[5, 5, 5],
          [6, 6, 6]]]
      expect(sess.run(tf.shape(t))).to eq([3, 2, 3])
      expect(sess.run(tf.reshape(t, [-1]))).to eq([1, 1, 1, 2, 2, 2, 3, 3, 3, 4, 4, 4, 5, 5, 5, 6, 6, 6])
      expect(sess.run(tf.reshape(t, [2, -1]))).to eq([[1, 1, 1, 2, 2, 2, 3, 3, 3],
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
        sess.run(tf.reshape(t,[3,2,2]))
      }.to raise_exception

    end

    it "inference" do
      t = [[[1, 1, 1],
            [2, 2, 2]],
            [[3, 3, 3],
            [4, 4, 4]],
            [[5, 5, 5],
            [6, 6, 6]]]

      expect(sess.run(tf.reshape(t, [-1, 9]))).to eq([[1, 1, 1, 2, 2, 2, 3, 3, 3],
        [4, 4, 4, 5, 5, 5, 6, 6, 6]])
      
      expect(sess.run(tf.reshape(t, [ 2, -1, 3]))).to eq(
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
      @sess = create_session
    end
  
    [
      [[],    0.1915,       0.383         ],
      [[1],   [0.1915],       [0.383]        ],
      [[2,3], [[0.1915, 0.6221, 0.4377], [0.7854, 0.78, 0.2726]],  [[0.383, 1.2442, 0.8755], [1.5707, 1.56, 0.5452]] ]
    ].each do |shape, expected, range_expected|
      describe "shape #{shape}" do
        it "generates random uniform values" do
          expect(tr(@sess.run(tf.random_uniform(shape)))).to eq(expected)
        end

        specify "with ranges" do
          expect(tr(@sess.run(tf.random_uniform(shape, minval: 0, maxval: 2)))).to eq(range_expected)
        end
      end
    end

    context "shape (3,)" do
      it "Creates an operation to generate a random set of values of the given shape" do
        vec = tf.random_uniform([3])
        expect(tr(@sess.run(vec))).to eq([0.1915, 0.6221, 0.4377])

        #evaluating again generates new values
        expect(tr(@sess.run(vec))).to eq([0.7854, 0.78, 0.2726])
      end
    end

    context "shape (2, 2)" do
      it "Creates an operation to generate a random set of values of the given shape" do
        vec = tf.random_uniform([2,2])
        expect(tr(@sess.run(vec))).to eq([[0.1915, 0.6221], [0.4377, 0.7854]])

        #evaluating again generates new values
        expect(tr(@sess.run(vec))).to eq([[0.78, 0.2726], [0.2765, 0.8019]])
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
      expect(sess.run(tf.pad(t, paddings))).to eq([0, 1, 2, 3, 0])
    end

    it "pads a tensor, rank 2" do
      t = tf.constant([[1, 2, 3], [4, 5, 6]])
      paddings = tf.constant([[1, 1], [2, 2]])

      expect(sess.run(tf.pad(t, paddings, mode: "CONSTANT"))).to eq(
        [[0, 0, 0, 0, 0, 0, 0],
         [0, 0, 1, 2, 3, 0, 0],
         [0, 0, 4, 5, 6, 0, 0],
         [0, 0, 0, 0, 0, 0, 0]]
      )

      paddings_2 = tf.constant([[0, 1], [0, 2]])
      expect(sess.run(tf.pad(t, paddings_2, mode: "CONSTANT"))).to eq(
        [
         [1, 2, 3, 0, 0],
         [4, 5, 6, 0, 0],
         [0, 0, 0, 0, 0]
        ]
      )

      paddings_3 = tf.constant([[1, 0], [2, 0]])
      expect(sess.run(tf.pad(t, paddings_3, mode: "CONSTANT"))).to eq(
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
      g = tf.gradients(p, [x])
      result = sess.run(g,  feed_dict: { x => 2})
      expect(tr(result)).to eq([12])
      expect(tr(sess.run(p, feed_dict: { x => 2}))).to eq(8)
  
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
        expect(sess.run(e)).to eq([[1.0, 0.0],[0.0, 1.0]])

        e = tf.eye(3)
        expect(sess.run(e)).to eq([[1.0, 0.0, 0.0], [0.0, 1.0, 0.0], [0.0, 0.0, 1.0]])

        e = tf.eye(3, num_columns: 2)
        expect(sess.run(e)).to eq([[1.0, 0.0], [0.0, 1.0], [0.0, 0.0]])
      end
    end

    specify "using in matrix multiplication" do
      a = tf.constant([[1.0, 2.0, 3.0], [1.0, 2.0, 3.0]])
      b = tf.constant([[0.1, 0.1], [0.1, 0.1], [0.2, 0.2]])
      m = tf.matmul(a, b)
      expect(tr(sess.run(m))).to eq([[0.9, 0.9], [0.9, 0.9]])

      g = tf.gradients(m, [a])
      expect(tr(sess.run(g))).to eq([[[0.2, 0.2, 0.4], [0.2, 0.2, 0.4]]])

      d_wra = tf.matmul(tf.eye(a.shape[0]), b, transpose_b: true)
      expect(tr(sess.run(d_wra))).to eq([[0.1, 0.1, 0.2], [0.1, 0.1, 0.2]])
    end
  end

  context ".gradients" do
    it "Constructs symbolic derivatives of sum of ys w.r.t. x in xs." do
      a = tf.constant(0.0)
      b = a * 2
      g = tf.gradients(a + b, [a, b], stop_gradients: [a, b])
      h = tf.gradients(a + b, [a, b])

      expect(sess.run(g)).to eq([1.0, 1.0])
      expect(sess.run(h)).to eq([3.0, 1.0])
    end

    it "using stop gradients" do
      a = tf.stop_gradient(tf.constant(0.0))
      b = tf.stop_gradient(a * 2)
      h = tf.gradients(a + b, [a, b])
      expect(sess.run(a+b)).to eq(0)
      expect((a+b).to_math).to eq("\n (\n  0.0 + \n  \n   (\n    0.0 * 2.0))")
      expect(sess.run(h)).to eq([1.0, 1.0])
    end

    it "computes gradient of sin" do
      var = tf.constant(1.0) # Must be a tf.float32 or tf.float64 variable.
      loss = tf.sin(var) # some_function_of() returns a `Tensor`.
      var_grad = tf.gradients(loss, [var])[0]

      expect(tr(sess.run(var_grad))).to eq(0.5403)
    end
  end

  context ".check_numerics" do
    specify do
      a = tf.constant([[0.0, 0.0, 1.0],[0.0, 1.0, 3.1]])
      c = tf.check_numerics(a, "a")
      expect(sess.run(c)).to eq(sess.run(a))

      b = tf.constant([[0.0, 0.0, 1.0],[Float::NAN, 1.0, 3.1]])
      d = tf.check_numerics(b, "b")
      expect { sess.run(d) }.to raise_exception
    end
  end

  context ".cond" do
    it "returns a specific tensor function depending on the value of the predicate"  do
      x = tf.constant(2.0)
      y = tf.constant(3.0)
      z = tf.multiply(x, y)

      result = tf.cond(x < y, tf.add(x, z), tf.square(y))
      result2 = tf.cond(x > y, -> { tf.add(x, z) }, -> { tf.square(y) })
      expect(sess.run(result)).to eq(8.0)
      expect(sess.run(result2)).to eq(9.0)
    end

    it "supports gradients" do
      x = tf.constant(2.0)
      y = tf.constant(3.0)
      z = tf.multiply(x, y)

      result = tf.cond(x < y, tf.add(x, z), tf.square(y))
      result2 = tf.cond(x > y, tf.add(x, z), tf.square(y))

      grad1 = tf.gradients(result, [x, y])
      grad2 = tf.gradients(result2, [x, y])

      expect(sess.run(grad1)).to eq([4.0, 2.0])
      expect(sess.run(grad2)).to eq([0.0, 6.0])
    end
  end

  context ".reduce_mean" do
    it "Computes the mean of elements across dimensions of a tensor" do
      x = tf.constant([[1.0, 1.0], [2.0, 2.0]])
      expect(sess.run(tf.reduce_mean(x))).to eq(1.5)
      expect(sess.run(tf.reduce_mean(x, 0))).to eq([1.5, 1.5])
      expect(sess.run(tf.reduce_mean(x, 1))).to eq([1.0, 2.0])

      y = tf.constant([[1.0, 1.0, 1.0], [2.0, 2.0, 3.0], [1.5, -1.1, 1.1]])
      expect(tr(sess.run(tf.reduce_mean(y)))).to eq(1.2778)
      expect(tr(sess.run(tf.reduce_mean(y, 0)))).to eq([1.5, 0.6333, 1.7])
      expect(tr(sess.run(tf.reduce_mean(y, 1)))).to eq([1.0, 2.3333, 0.5])
    end

    it ".computes for the gradient" do
      x = tf.constant([[1.0, 1.0], [2.0, 2.0]])
      f = tf.reduce_mean(x)
      g = tf.gradients(f, [x])
      expect(sess.run(g)).to eq([[[0.25, 0.25], [0.25, 0.25]]])
    end
  end

  context ".tile" do
    it "Constructs a tensor by tiling a given tensor." do
      a = tf.constant([[1, 2, 3, 4], [1, 2, 3, 4]])
      expect(sess.run(tf.tile(a,[1, 0]))).to eq([])
      expect(sess.run(tf.tile(a,[0, 1]))).to eq([])
      expect(sess.run(tf.tile(a,[1, 1]))).to eq([[1, 2, 3, 4], [1, 2, 3, 4]])
      expect(sess.run(tf.tile(a,[2, 1]))).to eq([[1, 2, 3, 4], [1, 2, 3, 4], [1, 2, 3, 4], [1, 2, 3, 4]])
      expect(sess.run(tf.tile(a,[1, 2]))).to eq([[1, 2, 3, 4, 1, 2, 3, 4], [1, 2, 3, 4, 1, 2, 3, 4]])
    end
  end

  context "combination of functions" do
    it "add two operation together" do
      y = tf.sin(1.0) + tf.sin(2.0)
      expect(tr(sess.run(y))).to eq(1.7508)
    end
  end

  context ".max" do
    it "returns the maximum of two tensors" do
      a = tf.constant(1.0)
      b = tf.constant([1.0, 3.0])
      d = tf.constant([3.0, 1.1])
      c = tf.constant(2.1)
      expect(tr(sess.run(tf.max(a,c)))).to eq(2.1)
      expect(sess.run(tf.max(b,d))).to eq([3.0, 3.0])
    end

    it "computes for the gradient" do
      b = tf.constant([1.0, 3.0])
      d = tf.constant([3.0, 1.1])
      g = tf.gradients(tf.max(b,d), [b, d])
      expect(sess.run(g)).to eq([[0.0, 1.0], [0.0, 1.0]])
    end
  end

  context ".cast" do
    it "converts from one datatype to another" do
      a = tf.constant([1.0, 3.0])
      b = tf.constant([true, true])
      expect(sess.run(tf.cast(a, :int32))).to eql([1, 3])
      expect(sess.run(tf.cast(a, :boolean))).to eql([true, true])
      expect(sess.run(tf.cast(b, :float32))).to eql([1.0, 1.0])
      expect(sess.run(tf.cast(b, :int32))).to eql([1, 1])
    end
  end

  context ".less" do
    it "returns true if a < b" do
      a = tf.constant(2.0)
      b = tf.constant(3.0)
      expect(sess.run(tf.less(a, b))).to eq(true)
      expect(sess.run(tf.less(b, a))).to eq(false)
    end
  end


  context ".greater_equal" do
    it "returns true if a >= b elementwise" do
      a = tf.constant(1.0)
      b = tf.constant(1.0)
      c = tf.constant(2.1)
      d = tf.constant([1.1, 2.1, 3.0])
      e = tf.constant([1.1, 3.1, 1.1])
      expect(sess.run(tf.greater_equal(a,b))).to be
      expect(sess.run(a >= b)).to be
      expect(sess.run(tf.greater_equal(b,c))).to be false
      expect(sess.run(tf.greater_equal(d,e))).to eq([true, false, true])
    end
  end

  context ".less_equal" do
    it "returns true if a >= b elementwise" do
      a = tf.constant(1.0)
      b = tf.constant(1.0)
      c = tf.constant(2.1)
      d = tf.constant([1.1, 2.1, 3.0])
      e = tf.constant([1.1, 3.1, 1.1])
      expect(sess.run(tf.less_equal(a,b))).to be
      expect(a <= b).to be
      expect(sess.run(tf.less_equal(b,c))).to be true
      expect(sess.run(tf.less_equal(d,e))).to eq([true, true, false])
    end
  end

  context ".equal" do
    it "returns the truth value of two tensors" do
      a = tf.constant(1.0)
      b = tf.constant(1.0)
      c = tf.constant(2.1)
      d = tf.constant([[1.0]])
      e = tf.constant([[1.0]])
      f = tf.constant([[2.0]])
      expect(sess.run(tf.equal(a, b))).to eq(true)
      expect(sess.run(tf.equal(a, c))).to eq(false)
      expect(sess.run(tf.equal(d, e))).to eq([[true]])
      expect(sess.run(tf.equal(e, f))).to eq([[false]])

      expect(sess.run(a == b)).to eq(true)
      expect(sess.run(a == c)).to eq(false)
    end
  end


  context ".logical_and" do
    it "Returns the truth value of x AND y element-wise." do
      a = tf.constant([[true, true], [false, true]])
      b = tf.constant([[true, true], [true, true]])
      f = tf.logical_and(a, b)
      expect(sess.run(f)).to eq([[true, true], [false, true]])

      f = a.and(b)
      expect(sess.run(f)).to eq([[true, true], [false, true]])
    end
  end

  context ".not_equal" do
    it "returns the truth value of two tensors" do
      a = tf.constant(1.0)
      b = tf.constant(1.0)
      c = tf.constant(2.1)
      d = tf.constant([[1.0]])
      e = tf.constant([[1.0]])
      f = tf.constant([[2.0]])
      expect(sess.run(tf.not_equal(a, b))).to eq(false)
      expect(sess.run(tf.not_equal(a, c))).to eq(true)
      expect(sess.run(tf.not_equal(d, e))).to eq([[false]])
      expect(sess.run(tf.not_equal(e, f))).to eq([[true]])

      expect(sess.run(a != b)).to eq(false)
      expect(sess.run(a != c)).to eq(true)
    end
  end

  context ".print" do
    it "behaves like identity but prints a message to stdout" do
      x = tf.constant([[2.0, 2.0], [3.0, 3.0]])
      y = tf.print(x, x, message: "this is a prefix")
      z = tf.sin(y)
      expect(tr(sess.run(z))).to eq([[0.9093, 0.9093], [0.1411, 0.1411]])
    end
  end

  context ".slice" do
    it "slices a tensor" do
      t = tf.constant([[[1, 1, 1], [2, 2, 2]],
        [[3, 3, 3], [4, 4, 4]],
        [[5, 5, 5], [6, 6, 6]]])
      expect(sess.run(tf.slice(t, [1, 0, 0], [1, 1, 3]))).to eq([[[3, 3, 3]]])
      expect(sess.run(tf.slice(t, [1, 0, 0], [1, 2, 3]))).to eq([[[3, 3, 3], [4, 4, 4]]])
      expect(sess.run(tf.slice(t, [1, 0, 0], [2, 1, 3]))).to eq([[[3, 3, 3]], [[5, 5, 5]]])
    end

    it "1D tensor slicing" do
      t  = tf.constant([1,2,3,4,5,6,7])
      expect(sess.run(tf.slice(t, [2], [1]))).to eq([3])
    end
  end

  context ".rank" do
    it "returns the rank of a tensor" do
      t1 = tf.constant([[[1, 1, 1], [2, 2, 2]], [[3, 3, 3], [4, 4, 4]]])
      t2 = tf.constant(1)
      t3 = tf.constant([1,2])
      rank1 = tf.rank(t1)
      rank2 = tf.rank(t2)
      rank3 = tf.rank(t3)
      expect(sess.run(rank1)).to eq(3)
      expect(sess.run(rank2)).to eq(0)
      expect(sess.run(rank3)).to eq(1)
    end
  end

  context ".negate" do
    it "computes the negative of a tensor" do
      x = tf.constant(0.1)
      y = tf.constant([[1.1, 16.1], [2.1, 3.0]])
      z = -tf.constant(4.1)
      x_negate = tf.negate(x)
      y_negate = tf.negate(y)

      expect(tr(sess.run(x_negate))).to eq(-0.1)
      expect(tr(sess.run(y_negate))).to eq([[-1.1, -16.1], [-2.1, -3.0]])
      expect(tr(sess.run(z))).to eq(-4.1)
    end
  end

  context ".abs" do
    it "Computes the absolute value of a tensor" do
      tf = TensorStream

      a = [[1,2],[-1, 2], [3,-3]]
      b = -1.123

      expect(sess.run(tf.abs(a))).to eq([[1, 2], [1, 2], [3, 3]])
      expect(tr(sess.run(tf.abs(b)))).to eq(1.123)
    end

    specify "should compute for the gradient" do
      a = tf.constant([[1,2],[-1, 2], [3,-3]])
      expect(sess.run(tf.gradients(tf.abs(a),[a]))).to eq([[[ 1,  1],
        [-1,  1],
        [ 1, -1]]])
    end
  end

  context ".sign" do
    it "Returns an element-wise indication of the sign of a number." do
      tf = TensorStream

      a = tf.constant([[1,2],[-1, 2], [3,-3]])
      b = -1.123

      expect(sess.run(tf.sign(a))).to eq([[1, 1], [-1, 1], [1, -1]])
      expect(sess.run(tf.sign(b))).to eq(-1.0)
    end
  end

  context ".transpose" do
    it "transposes matrices" do
      tf.program do |tf|
        x = tf.constant([[1, 2, 3], [4, 5, 6]])
        t = tf.transpose(x)

        expect(sess.run(t)).to eq([[1, 4], [2, 5], [3, 6]])
      end
    end
  end
  context ".zeros" do
    it "generates a zero tensor" do
      a = tf.zeros([2,2])
      expect(sess.run(a)).to eq([[0.0, 0.0], [0.0, 0.0]])
    end
  end

  context ".ones" do
    it "generates a ones tensor" do
      ones = tf.ones([2,2])
      expect(sess.run(ones)).to eq([[1.0, 1.0], [1.0, 1.0]])
    end
  end

  context ".where" do
    it "does an elementwise comparison and picks the appropriate element from x or y" do
      a = tf.constant([1,2,3,4,5])
      b = tf.constant([6,6,6,6,6])
      c = tf.constant([8,8,8,8,8])

      expect(sess.run(tf.where(a > 3, b, c))).to eq([8, 8, 8, 6, 6])
    end

    it "supports gradients" do
      a = tf.constant([1,2,3,4,5])
      b = tf.constant([6,6,6,6,6])
      c = tf.constant([8,8,8,8,8])

      expr = tf.where(a > 3, b, c)
      g = tf.gradients(expr, [b, c])
      expect(sess.run(g)).to eq([[0, 0, 0, 1, 1], [1, 1, 1, 0, 0]])
    end
  end

  context "op level seed" do
    it "is able to set an op level seed" do
      a = tf.random_uniform([1], seed: 1)
      sess = tf.session
      expect(sess.run(a)).to eq([0.417022004702574])
      expect(sess.run(a)).to eq([0.7203244934421581])

      sess2 = tf.session
      expect(sess2.run(a)).to eq([0.417022004702574])
      expect(sess2.run(a)).to eq([0.7203244934421581])
    end
  end

  context ".convert_to_tensor" do
    it "converts native types and wraps them in a tensor" do
      op = tf.convert_to_tensor([1,2,3,4])
      expect(op.name).to eq("Const:1")
      expect(op.data_type).to eq(:int32)
      expect(sess.run(op)).to eq([1,2,3,4])
    end
  end

  context ".random_uniform_initializer" do
    it "initializes variables using the random uniform initializer" do
      tf.set_random_seed(1234)
      u = tf.get_variable('v', shape: [], dtype: :float32, initializer: tf.random_uniform_initializer)
      sess.run(tf.global_variables_initializer)
      expect(tr(sess.run(u))).to eq(0.1915)
    end
  end

  context ".zeros_initializer" do
    specify do
      u = tf.get_variable('v', shape: [], dtype: :float32, initializer: tf.zeros_initializer)
      sess.run(tf.global_variables_initializer)
      expect(tr(sess.run(u))).to eq(0.0)
    end
  end

  context ".assign_add" do
    [ [[],    1.0                      ],
      [[1],   [1.0]                     ],
      [[2],   [1.0, 1.0]                ],
      [[2,2], [[1.0, 1.0], [1.0, 1.0]]  ]
    ].each do |shape, expected|
      context "shape #{shape}" do
        it "adds a value to the current variable" do
          v = TensorStream.get_variable("v", shape: shape, initializer: TensorStream.zeros_initializer)
          assignment = v.assign_add(1)
          sess.run(TensorStream.global_variables_initializer)
          expect(sess.run(assignment)).to eq(expected)
        end
      end
    end
  end

  context ".assign" do
    specify "assign should set value" do
      w = TensorStream.variable(rand, name: "weight", initializer: TensorStream.zeros_initializer)
      sess.run(TensorStream.global_variables_initializer)
      sess.run(w.assign(2))
      expect(tr(w.read_value)).to eq(2)
    end
  end

  context ".greater" do
    it "returns true if a > b" do
      a = tf.constant(2.0)
      b = tf.constant(3.0)
      expect(sess.run(tf.greater(a, b))).to eq(false)
      expect(sess.run(tf.greater(b, a))).to eq(true)
    end

    it "handles rank 1 or higher" do
      a = tf.constant([[1.1, 1.3], [1.3, 1.2]])
      c = a > 0
      expect(sess.run(c)).to eq([[true, true], [true, true]])
    end
  end

  context ".pow" do
    it "Computes the power of tensor x to tensor y" do
      x = tf.constant([[2, 2], [3, 3]])
      y = tf.constant([[8, 15], [2, 3]])
      p = tf.pow(x, y)  # [[256, 65536], [9, 27]]
      expect(sess.run(p)).to eq([[256, 32768], [9, 27]])

      p = tf.pow(x, 2)
      expect(sess.run(p)).to eq([[4, 4], [9, 9]])
    end

    it "gradients of the power rule" do
      x = tf.constant([[1.1, 1.3], [1.3, 1.2]])
      y = tf.constant([[1.5, 2.0], [1.1, 2.0]])
      p = tf.pow(x, y)  # [[256, 65536], [9, 27]]
      g = tf.gradients(p, [x, y])
      expect(tr(sess.run(g))).to eq([
        [[1.5732, 2.6], [1.1292, 2.4]],
        [[0.11, 0.4434], [0.3501, 0.2625]]
      ])
    end
  end

  context ".argmin" do
    it "Returns the index with the smallest value across axes of a tensor. " do
      a = tf.constant([
        [31, 23,  4, 24, 27, 34],
        [18,  3, 25,  0,  6, 35],
        [28, 14, 33, 22, 20,  8],
        [13, 30, 21, 19,  7,  9],
        [16,  1, 26, 32,  2, 29],
        [17, 12,  5, 11, 10, 15]])

      b = tf.constant([1,2,3,4,5,6])
      expect(sess.run(tf.argmin(a))).to eq([3, 4, 0, 1, 4, 2])
    end
  end

  context '.argmax' do
    it 'Returns the index with the largest value across axes of a tensor. (deprecated arguments)' do
      a = tf.constant([
        [31, 23,  4, 24, 27, 34],
        [18,  3, 25,  0,  6, 35],
        [28, 14, 33, 22, 20,  8],
        [13, 30, 21, 19,  7,  9],
        [16,  1, 26, 32,  2, 29],
        [17, 12,  5, 11, 10, 15]])

      b = tf.constant([1,2,3,4,5,6])
      expect(sess.run(tf.argmax(a))).to eq([0, 3, 2, 4, 0, 1])
      expect(sess.run(tf.argmax(a, 1))).to eq([5, 5, 2, 1, 3, 0])
      expect(sess.run(tf.argmax(a, 0))).to eq([0, 3, 2, 4, 0, 1])
      expect(sess.run(tf.argmax(b, 0))).to eq(5)
      expect(sess.run(tf.argmax(b, 0, output_type: :float32))).to eql(5.0)
    end
  end

  context ".add standard" do
    it "adds 2 tensors element-wise" do
      a = tf.constant(1.0)
      b = tf.constant(2.0)
      expect(sess.run(tf.add(a, b))).to eq(3.0)

      a = tf.constant([1.0, 1.1])
      b = tf.constant([2.0, 1.5])
      expect(tr(sess.run(tf.add(a, b)))).to eq([3.0, 2.6])
    end

    specify "supports broadcasting" do
      a = tf.constant([1.0, 1.1])
      b = tf.constant(2.0)
      expect(tr(sess.run(tf.add(a, b)))).to eq([3.0, 3.1])
    end

    specify "supports broadcasting rank > 1" do
      a = tf.constant([[1.0, 1.1],[2.2, 1.2]])
      b = tf.constant([2.0, 2.1])
      expect(tr(sess.run(tf.add(a, b)))).to eq([[3.0, 3.2], [4.2, 3.3]])

      a = tf.constant([[1.0, 1.1],[2.2, 1.2]])
      b = tf.constant([[2.0], [2.1]])
      expect(tr(sess.run(tf.add(a, b)))).to eq([[3.0, 3.1], [4.3, 3.3]])

      a = tf.constant([[1, 2, 3], [4, 5, 6]])
      b = tf.constant([1, 2, 3])
      d = a + b
      expect(sess.run(d)).to eq([[2, 4, 6], [5, 7, 9]])
    end

    specify do
      a = tf.constant([1.0, 1.1])
      b = tf.constant([2.0, 1.5])

      c = tf.constant(2.0)

      sum1 = a + b
      sum2 = sum1 + c
      expect(tr(sess.run(sum2))).to eq([5.0, 4.6])
    end
  end

  context ".sub" do
    let(:a) { tf.constant([1.0, 2.0, 3.0])}
    let(:b) { tf.constant([0.1, 0.2, 0.3])}
    let(:c) { tf.constant(0.1) }
    let(:m) { tf.constant([[1.0, 2.0, 3.0], [2.0, 3.0 ,4.0], [5.0, 6.0, 7.0], [8.0, 9.0, 10.0]]) }

    it "substracts two arrays" do
      expect(tr(sess.run((a - b)))).to eq([0.9, 1.8, 2.7])
    end

    it "substracts an array and a constant" do
      expect(tr(sess.run((a - c)))).to eq([0.9, 1.9, 2.9])
    end

    it "substracts a matrix and an array" do
      expect(tr(sess.run((m - a)))).to eq([[0.0, 0.0, 0.0], [1.0, 1.0, 1.0], [4.0, 4.0, 4.0], [7.0, 7.0, 7.0]])
    end

    specify "gradients" do
      expect(sess.run(tf.gradients(a - b, [a,b]))).to eq([[1.0, 1.0, 1.0], [-1.0, -1.0, -1.0]])
    end
  end

  describe "randomization functions" do
    before do
      tf.set_random_seed(1234)
      @sess = tf.session
    end

    context ".random_normal" do
      [
        [[],    0.5011628459350929],
        [[1],   [0.5011628459350929] ],
        [[2,3], [[0.5011628459350929, 1.301972948852967, -1.621722019401658], [0.6690221526288901, 0.14937983113945622, -0.783723693080629]] ],
      ].each do |shape, expected|
        describe "shape #{shape}" do
          it "generates random normal values" do
            r = tf.random_normal(shape)
            expect(tr(sess.run(r))).to eq(tr(expected))
          end
        end
      end
    end
  end

  context ".div" do
    let(:a) { tf.constant(2.5) }
    let(:b) { tf.constant(3.1) }

    it "divides to tensors" do
      op = a / b
      expect(tr(sess.run(op))).to eq(0.8065)
    end

    it "supports gradients" do
      grad = tf.gradients(a/b, [a,b])
      expect(tr(sess.run(grad))).to eq([0.3226, -0.2601])
    end
  end

  context ".mul" do
    it "performs elementwise multiplication" do
      a = tf.constant([[1, 2, 3], [4, 5, 6]])

      # c = a * 6
      # expect(sess.run(c)).to eq([[6, 12, 18], [24, 30, 36]])

      b = tf.constant([1, 2, 3])
      d = a * b
      expect(sess.run(d)).to eq([[1, 4, 9], [4, 10, 18]])
    end

    it "constant multiplication" do
      a= tf.constant([[1, 2, 3], [4, 5, 6]])
      c = tf.constant(6) * a
      expect(sess.run(a)).to eq([[1, 2, 3], [4, 5, 6]])

      b= tf.constant([1,2,3,4,5,6])
      d= tf.constant(6) * b
      expect(sess.run(d)).to eq([6, 12, 18, 24, 30, 36])
    end

    it "handles two rank 1 tensors" do
      a = tf.constant([7.0, 7.0, 7.0, 7.0, 7.0])
      b = tf.constant([-0.1079, 2.281999999999999, 1.1489, -0.5005000000000001, -3.5218999999999996])
      c = a * b
      expect(tr(sess.run(c))).to eq([-0.7553, 15.974, 8.0423, -3.5035, -24.6533])
    end

    it "handles different rows" do
      a = tf.constant([[1.0, 1.0], [1.0, 1.0]])
      b = tf.constant([[4.0, 4.0]])
      c = a * b
      expect(sess.run(c)).to eq([[4.0, 4.0], [4.0, 4.0]])
    end

    it "different rank multiplication" do
      a = tf.constant([7.0, 7.0, 7.0, 7.0, 7.0])
      b = tf.constant([[2.0, 2.0, 2.0, 2.0, 2.0], [1.0, 1.0, 1.0, 1.0, 1.0]])
      c = a * b
      expect(sess.run(c)).to eq([[14.0, 14.0, 14.0, 14.0, 14.0], [7.0, 7.0, 7.0, 7.0, 7.0]])
    end

    specify "broadcasting" do
      a = tf.constant([[1.0, 1.1], [2.0, 1.0], [1.0, 1.1]])
      b = tf.constant([[1.2], [1.1], [0.2]])
      f = a * b
      expect(tr(sess.run(f))).to eq([[1.2, 1.32], [2.2, 1.1], [0.2, 0.22]])
      f = b * a
      expect(tr(sess.run(f))).to eq([[1.2, 1.32], [2.2, 1.1], [0.2, 0.22]])
    end
  end

  context ".matmul" do
    it "performs matrix multiplication" do
      a = tf.constant([1, 2, 3, 4, 5, 6], shape: [2, 3])
      b = tf.constant([7, 8, 9, 10, 11, 12], shape: [3, 2])
      c = tf.matmul(a, b)
      expect(sess.run(c)).to eq([[ 58,  64],
                            [139, 154]])

      c = a.matmul(b)
      expect(sess.run(c)).to eq([[ 58,  64],
      [139, 154]])

      d = tf.matmul(a, b, transpose_a: true, transpose_b: true)
      expect(sess.run(d)).to eq([[39, 49, 59], [54, 68, 82], [69, 87, 105]])
    end

    specify "gradients" do
      a = tf.constant([[1.0, 2.0, 3.0], [4.0, 5.0, 6.0]])
      b = tf.constant([[7.0, 8.0, 9.0], [10.0, 11.0, 12.0], [10.0, 11.0, 12.0]])

      y = tf.matmul(a, tf.sin(b))

      expect(tr(sess.run(y))).to eq([[-2.0631, -4.0106, -2.2707], [-3.3563, -7.0425, -4.2538]])

      g = tf.gradients(y, [a, b])

      expect(tr(sess.run(g))).to eq([[[2.0585, -2.0806, -2.0806], [2.0585, -2.0806, -2.0806]], [[3.7695, -0.7275, -4.5557], [-5.8735, 0.031, 5.907], [-7.5516, 0.0398, 7.5947]]])
    end
  end

  context "math functions" do
    # tests for single parameter algebra functions
    [
      [:sin, 0.0998,   [[0.8912,  0.8632], [0.8632, 0.1411]],  0.995, [[0.4536,  -0.5048], [-0.5048, -0.99]]                      ],
      [:cos, 0.995,    [[0.4536, -0.5048], [-0.5048, -0.99]], -0.0998, [[-0.8912,-0.8632], [-0.8632, -0.1411]]                   ],
      [:tan, 0.1003,   [[1.9648, -1.7098], [-1.7098, -0.1425]], 1.0101,  [[4.8603, 3.9236], [3.9236, 1.0203]]                     ],
      [:tanh, 0.0997,  [[0.8005,  0.9705], [0.9705, 0.9951]],      0.9901, [[0.3592, 0.0582], [0.0582, 0.0099]]                         ],
      [:log, -2.3026,  [[0.0953,  0.7419], [0.7419, 1.0986]],   10.0, [[0.9091, 0.4762], [0.4762, 0.3333]]                        ],
      [:exp, 1.1052,   [[3.0042, 8.1662], [8.1662, 20.0855]], 1.1052, [[3.0042, 8.1662], [8.1662, 20.0855]]          ],
      [:square, 0.01,  [[1.21, 4.41], [4.41, 9.0]],          0.2, [[2.2, 4.2], [4.2, 6.0]]                                    ],
      [:negate, -0.1,  [[-1.1, -2.1], [-2.1, -3.0]],         -1.0, [[-1.0, -1.0], [-1.0, -1.0]]                                 ],
      [:identity, 0.1, [[1.1, 2.1], [2.1, 3.0]],             1.0, [[1, 1], [1, 1]]                                              ],
      [:abs, 0.1,      [[1.1, 2.1], [2.1, 3.0]],             1.0, [[1, 1], [1, 1]]                                              ],
      [:sqrt, 0.3162,  [[1.0488, 1.4491], [1.4491, 1.7321]],   1.5811, [[0.4767,  0.345], [ 0.345, 0.2887]]                       ],
      [:reciprocal, 10.0, [[0.9091,  0.4762], [0.4762, 0.3333]], -100,  [[-0.8264,  -0.2268], [-0.2268, -0.1111]]                         ],
      [:sigmoid, 0.525, [[0.7503, 0.8909], [0.8909, 0.9526]], 0.2494, [[0.1874, 0.0972], [0.0972, 0.0452]]]
    ].each do |func, scalar, matrix, gradient, gradient2|
      context ".#{func}" do
        let(:x) { tf.constant(0.1) }
        let(:y) {  tf.constant([[1.1, 2.1], [2.1, 3.0]]) }
        let(:f_x) { tf.send(func,x) }
        let(:f_y) { tf.send(func,y) }

        specify "scalar #{func} value" do
          expect(tr(sess.run(f_x))).to eq(scalar)
        end

        specify "matrix #{func} values" do
          expect(tr(sess.run(f_y))).to eq(matrix)
        end

        specify "gradient #{func} values" do
          grad = tf.gradients(f_x, [x]).first
          grad_2 = tf.gradients(f_y, [y]).first

          expect(tr(sess.run(grad))).to eq(tr(gradient))
          expect(tr(sess.run(grad_2))).to eq(tr(gradient2))
        end
      end
    end
end

context "#broadcast" do
  context "gets compatible shapes for two tensors" do
    specify "scalar vs scalar" do
      expect(instance.broadcast(1.0, 1.0)).to eq([1.0, 1.0])
    end

    specify "1D vs constant" do
      expect(instance.broadcast([1.0, 2.0], 1.0)).to eq([[1.0, 2.0], [1.0, 1.0]])
      expect(instance.broadcast([1.0, 2.0, 1.0], 1.0)).to eq([[1.0, 2.0, 1.0], [1.0, 1.0, 1.0]])
    end

    specify "1D vs 1D" do
      expect(instance.broadcast([1.0, 2.0], 1.0)).to eq([[1.0, 2.0], [1.0, 1.0]])
      expect(instance.broadcast([1.0, 2.0, 3.0], [1.0])).to eq([[1.0, 2.0, 3.0], [1.0, 1.0, 1.0]])
    end

    specify "2D vs 1D" do
      expect(instance.broadcast([[1.0, 2.0], [1.0, 2.0]], 1.0)).to eq([[[1.0, 2.0], [1.0, 2.0]], [[1.0, 1.0], [1.0, 1.0]]])
      expect(instance.broadcast([[1.0, 2.0], [1.0, 2.0]], [1.0])).to eq([[[1.0, 2.0], [1.0, 2.0]], [[1.0, 1.0], [1.0, 1.0]]])
      expect(instance.broadcast([[1.0, 2.0], [1.0, 2.0]], [3.0, 3.1])).to eq([[[1.0, 2.0], [1.0, 2.0]], [[3.0, 3.1], [3.0, 3.1]]])
    end

    specify "2D vs 2D" do
      expect(instance.broadcast([[1.0, 2.0], [1.0, 2.0]], [[1.0], [1.0]])).to eq([[[1.0, 2.0], [1.0, 2.0]], [[1.0, 1.0], [1.0, 1.0]]])
      expect(instance.broadcast([[1.0, 2.0, 1.1], [1.0, 2.0, 2.2]], [[1.0], [2.0]])).to eq( [[[1.0, 2.0, 1.1], [1.0, 2.0, 2.2]], [[1.0, 1.0, 1.0], [2.0, 2.0, 2.0]]])
    end
  end
end

context "#broadcast_dimensions" do
  it "can broadcast various tensors in various shapes" do
    a = [1.0]
    expect(instance.broadcast_dimensions(a, [5])).to eq([1.0, 1.0, 1.0, 1.0, 1.0, 1.0])
    expect(instance.broadcast_dimensions(a, [2, 1])).to eq([[1.0, 1.0], [1.0, 1.0]])
    expect(instance.broadcast_dimensions(a, [3, 1])).to eq([[1.0, 1.0], [1.0, 1.0], [1.0, 1.0]])

    a = [[1.0, 2.0]]
    b = [[1.0],[2.0]]
    expect(instance.broadcast_dimensions(a, [3, 0])).to eq([[1.0, 2.0], [1.0, 2.0], [1.0, 2.0], [1.0, 2.0]])
    expect(instance.broadcast_dimensions(b, [0, 1])).to eq([[1.0, 1.0], [2.0, 2.0]])
    expect(instance.broadcast_dimensions(a, [])).to eq([[1.0, 2.0]])
    expect(instance.broadcast_dimensions(b, [])).to eq([[1.0], [2.0]])
    expect(instance.broadcast_dimensions([1.0], [2, 1])).to eq([[1.0, 1.0], [1.0, 1.0]])
  end
end

context ".shape" do
  it "returns a 1D tensor representing shape of target tensor" do
    t = tf.constant([[[1, 1, 1], [2, 2, 2]], [[3, 3, 3], [4, 4, 4]]])
    shape = tf.shape(t)
    expect(sess.run(shape)).to eq([2, 2, 3])

    u = tf.constant(1)
    shape = tf.shape(u)
    expect(sess.run(shape)).to eq([])

    v = tf.constant([[1,2,3],[4,5,6]])
    shape = tf.shape(v)
    expect(sess.run(shape)).to eq([2 ,3])
  end

  it "can set out_type to return a float" do
    v = tf.constant([[1, 2, 3],[4, 5, 6]])
    shape = tf.shape(v, out_type: :float32)
    expect(sess.run(shape)).to eql([2.0, 3.0])
  end
end

context ".reduce_sum" do
  it "computes the sum of elements across dimensions of a tensor." do
    x = tf.constant([[1, 1, 1], [1, 1, 1]])

    expect(sess.run(tf.reduce_sum(x))).to eq(6)
    expect(sess.run(tf.reduce_sum(x, 0))).to eq([2, 2, 2])
    expect(sess.run(tf.reduce_sum(x, 1))).to eq([3, 3])
    expect(sess.run(tf.reduce_sum(x, 1, keepdims: true))).to eq([[3], [3]])
    expect(sess.run(tf.reduce_sum(x, [0, 1]))).to eq(6)

    expect(sess.run(tf.reduce_sum(x, []))).to eq([[1, 1, 1], [1, 1, 1]]) # no reduction
    expect(sess.run(tf.reduce_sum([[1, 1], [1, 1], [1, 1]]))).to eq(6)
  end

  it "negative axis" do
    x = tf.constant([[1, 1, 1], [1, 1, 1]])

    expect(sess.run(tf.reduce_sum(x, -1))).to eq([3, 3])
    expect(sess.run(tf.reduce_sum(x, -2))).to eq([2, 2, 2])
  end

  it "rank > 2 tensor" do
    x = tf.constant([ [[1,1], [1,1]], [[1,1], [1,1]]])
    expect(sess.run(tf.reduce_sum(x))).to eq(8)
    expect(sess.run(tf.reduce_sum(x, [1, 0]))).to eq([4, 4])
    expect(sess.run(tf.reduce_sum(x, 0))).to eq([[2, 2],[2, 2]])

    y = tf.constant([[1.0, 2.0], [0.4, 4.1], [0.2, 4.2]])
    expect(tr(sess.run(tf.reduce_sum(y, [1], keepdims: true)))).to eq([[3.0], [4.5], [4.4]])
  end

  specify "computes the gradients properly" do
    a = tf.constant([[1,2,3],[4,5,6]])
    op = tf.reduce_sum(a)
    expect(sess.run(tf.gradients(op,[a]))).to eq([[[1, 1, 1], [1, 1, 1]]])
  end
end

context ".reduce_prod" do
  it "computes the sum of elements across dimensions of a tensor." do
    x = tf.constant([[2, 1, 2], [2, 1, 2]])
    expect(sess.run(tf.reduce_prod(x))).to eq(16)
    expect(sess.run(tf.reduce_prod(x, 0))).to eq([4, 1, 4])
    expect(sess.run(tf.reduce_prod(x, 1))).to eq([4, 4])
    expect(sess.run(tf.reduce_prod(x, 1, keepdims: true))).to eq([[4], [4]])
    expect(sess.run(tf.reduce_prod(x, [0, 1]))).to eq(16)
  end

  xit "reduceing an empty array" do #fails for opencl
    x = tf.constant([])
    y = tf.constant([[], []])
    expect(sess.run(tf.reduce_prod(x))).to eq(1.0)
    expect(sess.run(tf.reduce_prod(y, 0))).to eq([])
    expect(sess.run(tf.reduce_prod(y, 1))).to eq([1.0, 1.0])
  end

  xspecify "computes the gradients properly" do
    a = tf.constant([[1,2,3],[4,5,6]])
    op = tf.reduce_prod(a)
    expect(sess.run(tf.gradients(op,[a]))).to eq([[720, 360, 240],[180, 144, 120]])
  end
end

context ".zeros_like" do
  it "generates a zero tensor based on another tensor" do
    a = tf.zeros_like([2,2,2,2,2])
    b = tf.zeros_like([[2,2],[3,3]])
    expect(sess.run(a)).to eq([0, 0, 0, 0, 0])
    expect(sess.run(b)).to eq([[0, 0], [0, 0]])
  end
end

context ".ones_like" do
  it "generates a zero tensor based on another tensor" do
    a = tf.ones_like([2, 2, 2, 2, 2])
    b = tf.ones_like([[2, 2],[3, 3]])
    expect(sess.run(a)).to eq([1, 1, 1, 1, 1])
    expect(sess.run(b)).to eq([[1, 1], [1, 1]])
  end
end

  context "multivariate functions" do
    let(:a)   { tf.constant(1.0) }
    let(:b)   { tf.constant(2.0) }
    let(:a_1) { tf.constant([1.0, 1.5]) }
    let(:b_1) { tf.constant([2.0, 0.1]) }
    let(:a_2) { tf.constant([[1.0, 1.5],[0.8,  0.2]]) }
    let(:b_2) { tf.constant([[2.0, 0.1],[3.0, 0.01]]) }

    def func_test(op, x, y, e1, e2)
      func = tf.send(op.to_sym, x, y)
      expect(tr(sess.run(func))).to eq(e1)
      grad = tf.gradients(func, [x, y])
      expect(tr(sess.run(grad))).to eq(e2)
    end

    [ 
      #op   rank 0   rank 1   rank 2   grad 0   grad 1  grad 2
      [:add, 3.0,  [3.0, 1.6],  [[3.0, 1.6], [3.8, 0.21]],    [1.0,  1.0],  [[1.0, 1.0], [1.0,   1.0]],  [[[1.0, 1.0], [1.0, 1.0]], [[1.0, 1.0], [1.0, 1.0]]] ],
      [:sub, -1.0, [-1.0, 1.4], [[-1.0, 1.4], [-2.2, 0.19]],  [1.0, -1.0],  [[1.0, 1.0], [-1.0, -1.0]],   [[[1.0, 1.0], [1.0, 1.0]], [[-1.0, -1.0], [-1.0, -1.0]]] ],
    ].each do |op, expected_0, expected_1, expected_2, expected_grad_0, expected_grad_1, expected_grad_2|
      context ".#{op}" do


        specify "basic scalar operation" do
          func_test(op, a, b, expected_0, expected_grad_0)
        end

        specify "basic rank 1 operation" do
          func_test(op, a_1, b_1, expected_1, expected_grad_1)
        end

        specify "basic rank 2 operation" do
          func_test(op, a_2, b_2, expected_2, expected_grad_2)
        end
      end
    end

    [
      [:add, [3.0, 3.5],   [[3.0, 3.5], [2.8, 2.2]], [[1.0, 1.0], 2.0],       [[[1.0, 1.0], [1.0, 1.0]], 4.0] ],
      [:sub, [-1.0, -0.5], [[-1.0, -0.5], [-1.2, -1.8]], [[1.0, 1.0], -2.0],  [[[1.0, 1.0], [1.0, 1.0]], -4.0] ],
    ].each do |op, expected_1_0, expected_2_0, grad_1_0, grad_2_0|
      context ".#{op}" do
        specify "mixed rank operation 1  vs 0" do
          func_test(op, a_1, b, expected_1_0, grad_1_0)
        end

        specify "mixed rank operation 2  vs 0" do
          func_test(op, a_2, b, expected_2_0, grad_2_0)
        end
      end
    end
  end

  context "nn ops" do

    context ".sigmoid_cross_entropy_with_logits" do
      it "Measures the probability error in discrete classification tasks" do
        labels = tf.constant([[1.0, 0.0, 1.0, 0.0, 1.0, 1.0, 0.0], [1.0, 0.0, 1.0, 0.0, 1.0, 1.0, 0.0]])
        outputs = tf.constant([[1.0, 2.0, 3.0, 4.0, 1.0, 2.0, 3.0], [1.0, 2.0, 3.0, 4.0, 1.0, 2.0, 3.0]])
        f = tf.nn.sigmoid_cross_entropy_with_logits(logits: outputs, labels: labels)
        expect(tr(sess.run(f))).to eq([[0.3133, 2.1269, 0.0486, 4.0181, 0.3133, 0.1269, 3.0486], [0.3133, 2.1269, 0.0486, 4.0181, 0.3133, 0.1269, 3.0486]])
      end

      specify "gradients" do
        labels = tf.constant([1.0, 0.0, 1.0, 0.0, 1.0, 1.0, 0.0])
        outputs = tf.constant([1.0, 2.0, 3.0, 4.0, 1.0, 2.0, 3.0])
        f = tf.nn.sigmoid_cross_entropy_with_logits(logits: outputs, labels: labels)
        g = tf.gradients(f, [labels, outputs])
        expect(tr(sess.run(g))).to eq([[-1.0, -2.0, -3.0, -4.0, -1.0, -2.0, -3.0], [-0.2689, 0.8808, -0.0474, 0.982, -0.2689, -0.1192, 0.9526]])
      end
    end

    context ".softmax" do
      it "computes for the softmax of a group of values" do
        outputs = tf.constant([[1.0, 2.0, 3.0, 4.0, 1.0, 2.0, 3.0],[1.0, 2.0, 3.0, 4.0, 1.0, 2.0, 3.0]])
        expect(tr(sess.run(tf.nn.softmax(outputs)))).to eq( [[0.0236, 0.0643, 0.1747, 0.4748, 0.0236, 0.0643, 0.1747], [0.0236, 0.0643, 0.1747, 0.4748, 0.0236, 0.0643, 0.1747]])
      end

      specify "rank 1D" do
        outputs = tf.constant([1.0, 1.0, 0.0])
        expect(tr(sess.run(tf.nn.softmax(outputs)))).to eq([0.4223, 0.4223, 0.1554])
      end

      specify "gradients" do
        outputs = tf.constant([1.0, 1.0, 0.0])
        sm = tf.nn.softmax(outputs)
        f = tf.sin(sm)
        g = tf.gradients(f, [outputs])

        result = sess.run(g)

        expect(tr(result,7)).to eq([[-0.005, -0.005, 0.0099]])
      end
    end
  end
end