require_relative 'grid'

class FullGrid < Grid

  def initialize(window, **opts)
    super(window, opts)
    @cratio, @rratio, @cell_size = 4, 2, 4
  end

private

  def draw
    grid(1, 1, @rows, @cols, @cell_size)
  end

end
