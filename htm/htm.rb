require_relative '../common/temporal_attributes'
require_relative '../common/inspector'
require_relative 'column'
require_relative 'input'

class HTM
  include Inspector
  include TemporalAttributes

  COLUMNS = 80
  INPUTS = 80
  INIT_INHIBITION_RADIUS = 10

  PUBLIC_VARS = %i(cycles learning num_columns num_inputs inhibition_radius active_columns active_cells cells columns inputs)
  HASH_ATTRS  = PUBLIC_VARS
  SHOW_ATTRS  = HASH_ATTRS - %i(cells columns inputs)

  attr_reader *PUBLIC_VARS
  show_fields *SHOW_ATTRS
  hash_fields *HASH_ATTRS

  temporal_attr :learning_cells, history: 3

  def initialize(**params)
    @pattern = params[:pattern]
    @learning = true
    @cycles = 0
    @num_columns, @num_inputs = COLUMNS, INPUTS
    @inhibition_radius = INIT_INHIBITION_RADIUS
    @inputs = Array.new(@num_inputs) { |i| Input.new(i) } 
    @columns = Array.new(@num_columns) { Column.new(self, @inputs) }
    @cells = @columns.flat_map(&:cells)
    @active_columns = []
    @active_cells = []
    self.learning_cells = []
  end

  def step(new_input=nil)
    reset!
    perform_temporal_pooling
    perform_spacial_pooling
  end

  # reset state
  #
  def reset!
    @cycles += 1
    new_input ||=  @pattern[@cycles % 2]
    @inputs.each.with_index { |inp, i| inp.value = new_input[i] }
    @active_columns = @columns.select { |c| c.active? }
    @cells.each(&:reset!)
  end

  # temporal pooling
  # 
  def perform_temporal_pooling
    @active_columns.each { |c| c.ensure_active_and_learning }
    @active_cells = @cells.select { |c| c.active? }
    self.learning_cells = @cells.select { |c| c.learning? }
    @cells.each { |c| c.snapshot! }

    if @cycles > 2
      @columns.each { |c| c.reinforce_cells }
      @columns.each { |c| c.generate_predictions }
    end
  end

  # spatial pooling
  # 1. reinforce the dendrites of active columns
  # 2. tune boost and permanence for inactive columns
  # 3. adjust inhibition radius based on average overlap
  #
  def perform_spacial_pooling
    @active_columns.each { |c| c.tune_proximal_dendrite }
    @columns.each { |c| c.tune_boost }
    adjust_inhibition_radius
  end

  # def while_learning
  #   @learning = true
  #   yield
  #   @learning = false
  # end

  def activity_ratio
    (@active_columns.count / num_columns.to_f).round(2)
  end

  def adjust_inhibition_radius
    @inhibition_radius = average_receptive_field_size
  end

  def average_receptive_field_size
    @columns.reduce(0) { |a,c| a + c.raw_overlap} / @columns.count
  end

end
