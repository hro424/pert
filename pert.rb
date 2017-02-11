#!/usr/bin/ruby

require 'csv'
require 'pp'

INDENT = "  "

class Node
  attr_accessor :incoming, :outgoing

  def initialize
    @outgoing = Array.new
    @incoming = Array.new
  end
end

class Activity
  attr_reader :aid, :activity, :duration
  attr_accessor :prev_activities, :next_activities
  attr_accessor :total_float, :free_float
  attr_accessor :head_node, :tail_node

  def initialize id, activity, duration
    @aid = id
    @activity = activity
    @duration = duration
    @prev_activities = Array.new
    @next_activities = Array.new
    @total_float = 0
    @free_float = 0
    @head_node = nil
    @tail_node = nil
  end

  def calc_total_float
    @total_float = @tail_node.lft - (@head_node.est + @duration)
  end

  def calc_free_float
    @free_float = @tail_node.est - (@head_node.est + @duration)
  end

  def dump_prev_activities
    buf = ""
    @prev_activities.each do |act|
      if act != nil
        buf += act.aid.to_s + " "
      end
    end
    return buf
  end

  def dump_next_activities
    buf = ""
    @next_activities.each do |act|
      if act != nil
        buf += act.aid.to_s + " "
      end
    end
    return buf
  end

  def dump_head_node
    if @head_node != nil
      return @head_node.eid
    end
    return ""
  end

  def dump_tail_node
    if @tail_node != nil
      return @tail_node.eid
    end
    return ""
  end
end

class Event < Node
  attr_reader :eid
  attr_accessor :dest_node
  attr_accessor :est, :lft
  attr_reader :est_finished

  @@count = 0

  def initialize
    super
    @eid = @@count
    @@count += 1
    @dest_node = Hash.new
    @est = 0
    @lft = 0
    @est_done = false
  end

  def is_est_empty
    return !@est_done
  end

  def calc_est
    @est = @incoming.map { |act|
      if act.head_node.is_est_empty
        act.head_node.calc_est
      end
      act.head_node.est + act.duration
    }.max.to_i
    @est_done = true
  end

  def calc_lft
    if @outgoing.length > 0
      @lft = @outgoing.map { |act|
        act.tail_node.est - act.duration
      }.min
    else
      @lft = @est
    end
  end
end

class ActivityList

  @@count = 0

  def initialize
    @table = Hash.new
    @all_events = Array.new
    @starting_activity = Activity.new "*", "dummy", 0
    @starting_event = nil
  end

  def load_csv file
    # row[0]: Activity ID
    # row[1]: Activity
    # row[2]: Duration
    # row[3..]: Dependencies

    # Build the acitivity lookup table
    CSV.foreach file do |row|
      if row.length > 3
        id = row[0]
        @table[id] = Activity.new id, row[1], row[2].to_i
      end
    end

    # Add predecessors to the table
    CSV.foreach file do |row|
      if row.length > 3
        id = row[0]
        pred_list = row[3..-1]

        act = @table[id]
        if pred_list[0] == '*'
          act.prev_activities.push @starting_activity
        else
          pred_list.each { |pred| act.prev_activities.push @table[pred] }
        end
        act.prev_activities.sort! { |l, r| l.aid <=> r.aid }
      end
    end

    # Build predecessor-successor relationships
    @table.each do |id, current|
      current.prev_activities.each do |pred|
        # The starting node is not on the table
        if pred != nil && pred.aid != "*"
          @table[pred.aid].next_activities.push current
        end
      end
      current.next_activities.sort! { |l, r| l.aid <=> r.aid }
    end
  end

  def create_event
    event = Event.new
    @all_events.push event
    return event
  end

  def fill_head_node
    @table.each_value do |current|
      if current.prev_activities[0] == nil
        current.head_node = create_event
        @starting_event = current.head_node
      else
        if current.prev_activities[0].tail_node == nil
          current.prev_activities[0].tail_node = create_event
        end
        current.head_node = current.prev_activities[0].tail_node
      end
      current.head_node.outgoing.push current
    end
  end

  def fill_tail_node
    @table.each_value do |current|
      if current.tail_node == nil
        if current.next_activities[0] == nil
          # The finishing node
          current.tail_node = create_event
        else
          # Register the event that kicks the next activities
          current.tail_node = current.next_activities[0].head_node
        end
      end
      current.tail_node.incoming.push current
    end
  end

  def create_dummy_activity
    return Activity.new "D" + @@count.to_s, "dummy", 0
  end

  def resolve_consistency
    tmp = Array.new
    @table.each_value do |act|
      if act.head_node.incoming.length != 0 &&
        act.prev_activities.length > act.head_node.incoming.length

        act.prev_activities.each do |pred|
          if !(act.head_node.incoming.include? pred)
            dummy_act = create_dummy_activity
            dummy_act.head_node = pred.tail_node
            dummy_act.tail_node = act.head_node
            pred.tail_node.outgoing.push dummy_act
            act.head_node.incoming.push dummy_act
            tmp.push dummy_act
            break
          end
        end
      end
    end

    tmp.each do |act|
      @table[act.aid] = act
    end
  end

  def insert_dummy activity
    head_node = activity.head_node
    head_node.outgoing.delete activity

    dummy_activity = Activity.new "D" + activity.aid, "dummy", 0
    head_node.outgoing.push dummy_activity
    dummy_activity.head_node = head_node

    dummy_event = Event.new
    dummy_activity.tail_node = dummy_event
    activity.head_node = dummy_event
    dummy_event.outgoing.push activity
    dummy_event.incoming.push dummy_activity

    @table[dummy_activity.aid] = dummy_activity
  end

  def resolve_duplicates
    @all_events.each do |evt|
      evt.outgoing.each do |act|
        if evt.dest_node[act.tail_node] == nil
          evt.dest_node[act.tail_node] = Array.new
        end
        evt.dest_node[act.tail_node].push act
      end

      evt.dest_node.each_value do |acts|
        acts.sort! { |l, r| r.duration <=> l.duration }
      end
    end

    tmp = Array.new
    @all_events.each do |evt|
      evt.dest_node.each_value do |edges|
        if edges.length > 1
            tmp += edges[1..-1]
        end
      end
    end

    tmp.each do |edge|
      insert_dummy edge
    end
  end

  def update
    for i in 1..3
      @all_events.each { |evt| evt.calc_est }
    end
    @all_events.each { |evt| evt.calc_lft }
    @table.each_value { |act|
      act.calc_total_float
      act.calc_free_float
    }
  end

  def dump
    print "---------+------------------+------------------+------------+------------\n"
    print "    ID   |       Prev       |       Next       | Prev Event | Next Event\n"
    print "---------+------------------+------------------+------------+------------\n"
    @table.each do |id, act|
      printf "%8s | %16s | %16s | %10s | %10s\n",
        act.aid, act.dump_prev_activities, act.dump_next_activities,
        act.dump_head_node, act.dump_tail_node
    end
  end

  def write file
    file.print "digraph \"PERT\" {\n"
    file.print "#{INDENT}rankdir = LR;\n"

    @table.each_value do |act|
      if act.tail_node != nil
        file.print "#{INDENT}#{act.head_node.eid} -> #{act.tail_node.eid} "
        if act.activity == "dummy"
          file.print "[ style = dashed ];\n"
        else
          file.print "[ "
          #if act.critical
          #  file.print "color = \"red\" "
          #end
          file.print "label = < <b>#{act.activity}</b><br/>"
          file.print "&#916;#{act.duration} "
          file.print "TF#{act.total_float} "
          file.print "FF#{act.free_float} > ];\n"
        end
      end
    end

    @all_events.each do |evt|
      file.print "#{INDENT}#{evt.eid} [ label = \"\\N\\nEST:#{evt.est}\\n"
      file.print "LFT:#{evt.lft}\" ];\n"
    end
    print "}\n"
  end
end

activity_list = ActivityList.new
activity_list.load_csv ARGV[0]
#activity_list.dump
activity_list.fill_head_node
#activity_list.dump
activity_list.fill_tail_node
#activity_list.dump
activity_list.resolve_consistency
activity_list.resolve_duplicates
#activity_list.dump
activity_list.update
#activity_list.dump
activity_list.write $stdout

