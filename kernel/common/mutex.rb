class Mutex
  def initialize
    @owner = nil
  end

  # Check and only allow it to be marshal'd if there are no waiters.
  def marshal_dump
    raise "Unable to dump locked mutex" unless @waiters.empty?
    1
  end

  # Implemented because we must since we use marshal_load PLUS we need
  # to create AND prime @lock. If we didn't do this, then Marshal
  # wouldn't prime the lock anyway.
  def marshal_load(bunk)
    initialize
  end

  def locked?
    Rubinius.locked?(self)
  end

  def try_lock
    # Locking implies a memory barrier, so we don't need to use
    # one explicitly.
    if Rubinius.try_lock(self)
      @owner = Thread.current
      true
    else
      false
    end
  end

  def lock
    Rubinius.memory_barrier
    if @owner == Thread.current
      raise ThreadError, "Recursively locking not allowed"
    end

    Rubinius.lock self
    @owner = Thread.current
    Rubinius.memory_barrier
    return self
  end

  def unlock
    Rubinius.memory_barrier

    if @owner != Thread.current
      raise ThreadError, "Not owner, #{@owner.inspect} is"
    end

    @owner = nil
    Rubinius.unlock self
  end

  def synchronize
    lock
    begin
      yield
    ensure
      unlock
    end
  end
end