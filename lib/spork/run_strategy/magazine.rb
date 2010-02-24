# this class' goal:
# to boldly just run test after test
# as they come in
require 'drb'
require 'rinda/ring'
require 'win32/process' if RUBY_PLATFORM =~ /mswin|mingw/

$:.unshift(File.dirname(__FILE__))
require 'magazine/magazine_slave'


class Spork::RunStrategy::Magazine < Spork::RunStrategy

  Slave_Id_Range = 1..2 # Ringserver uses id: 0. Slave use: 1..MAX_SLAVES

  def slave_max
    Slave_Id_Range.to_a.size
  end

  def initialize(test_framework)
    @test_framework = test_framework
    this_path = File.expand_path(File.dirname(__FILE__))
    @path = File.join(this_path, 'magazine')
    @pids = []

    @pids << start_Rinda_ringserver
    sleep 1

    fill_slave_pool
  rescue RuntimeError => e
    kill_all_processes
    raise e
  end

  def start_Rinda_ringserver
    app_name = 'ruby ring_server.rb'
    Process.create( :app_name => app_name, :cwd => @path ).process_id
  end

  def fill_slave_pool
    Slave_Id_Range.each do |id|
      start_slave(id)
    end
    puts "---- start to fill pool...------"; $stdout.flush
  end

  def start_slave(id)
    app_pwd = Dir.pwd  # path running app in
    app = "ruby magazine_slave_provider.rb #{id} #{app_pwd} #{@test_framework.short_name}"
    @pids[id] = Process.create( :app_name => app, :cwd => @path ).process_id
  end


  def self.available?
    true
  end

  def run(argv, stderr, stdout)
        DRb.start_service
        ts = Rinda::RingFinger.primary
        if ts.read_all([:name, :MagazineSlave, nil, nil]).size > 0
          print '  --> take tuple'; stdout.flush
          tuple = ts.take([:name, :MagazineSlave, nil, nil])
          slave = tuple[2]
          id = tuple[3]

          puts "(#{slave.id_num}); slave.run..."; $stdout.flush
          slave.run(argv,stderr,stdout)
          puts "  <-- (#{slave.id_num});run done"; $stdout.flush

          restart_slave(id)
#           kill_all_processes
        else
          puts '- NO tuple'; $stdout.flush
        end
  end

  def restart_slave(id)
    pid   = @pids[id]
    Process.kill(4, pid)
    start_slave(id)
  end

  def kill_all_processes

    @pids.each {|pid| Process.kill(4, pid)}
    puts "\nKilling processes."; $stdout.flush
  end

  def slave_count
    DRb.start_service
    ts = Rinda::RingFinger.primary
    ts.read_all([:name, :MagazineSlave, nil, nil]).size
  end


  def abort
    kill_all_processes
  end

  def preload
    true
    #    @test_framework.preload
  end

  def running?
    @running
  end

end