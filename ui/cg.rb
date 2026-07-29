#!/usr/bin/ruby
# cg.rb
# Simply Putty Connection Manger
# Alastair Montgomery 2014

require 'yaml'
require 'fox16'
require 'pp'
require 'open3'
include Fox

require File.expand_path(File.join(File.dirname(__FILE__), "lib/gen_ip"))

class SimplePC < FXMainWindow
  def initialize(app, title, w, h)

    #Load static data
    @myhash   = YAML.safe_load(File.read(File.expand_path(File.join(File.dirname(__FILE__), 'details.yaml'))), permitted_classes: [Symbol])
    @environments     = YAML.safe_load(File.read(File.expand_path(File.join(File.dirname(__FILE__), 'envs.yaml'))), permitted_classes: [Symbol])
    settings = YAML.safe_load(File.read(File.expand_path(File.join(File.dirname(__FILE__), 'settings.yaml'))), permitted_classes: [Symbol])

    @user = settings['user']
    @profile = settings['profile']
    @ssh_com = settings['app'] + " " + settings['profile']

    #Setup GUI
    super(app, title, :width => w, :height => h)
    add_menu_bar
    @h_frame1 = FXHorizontalFrame.new(self)
    @h_frame2 = FXHorizontalFrame.new(self)
    add_fields
    add_buttons
    add_text_area
  end

  def create
    super
    show(PLACEMENT_SCREEN)
  end

  private
  def add_menu_bar
    menu_bar = FXMenuBar.new(self, LAYOUT_SIDE_TOP | LAYOUT_FILL_X)
    file_menu = FXMenuPane.new(self)
    FXMenuTitle.new(menu_bar, "File", :popupMenu => file_menu)
    add_cmd = FXMenuCommand.new(file_menu, "Add Server")
    add_cmd.connect(SEL_COMMAND) do
      addNewServer
    end
    FXMenuSeparator.new(file_menu)
    exit_cmd = FXMenuCommand.new(file_menu, "Exit")
    exit_cmd.connect(SEL_COMMAND) do
      exit
    end
  end

  def add_text_area
    @txt = FXText.new(self, :opts => TEXT_READONLY|TEXT_WORDWRAP|LAYOUT_FILL)
    @txt.text = ""
  end

  def add_fields
    chr_label = FXLabel.new(@h_frame1,"Server")
    # @server_field = FXTextField.new(@h_frame1,15)
    @server_field = FXComboBox.new(@h_frame1,20,:opts => FRAME_SUNKEN|FRAME_THICK)
    chr_label = FXLabel.new(@h_frame1,"Environment")
    @env_field  = FXComboBox.new(@h_frame1,8,:opts => FRAME_SUNKEN|FRAME_THICK)
    @env_field.fillItems(@environments.keys)
    chr_label = FXLabel.new(@h_frame1,"Port")
    @port_field = FXTextField.new(@h_frame1,4)
    @port_field.text = "22"
  end

  def add_buttons
    connect_button = FXButton.new(@h_frame2,"Connect")
    list_button = FXButton.new(@h_frame2,"List")
    ping_button = FXButton.new(@h_frame2,"Ping")
    dump_button = FXButton.new(@h_frame2,"Dump")
    search_button = FXButton.new(@h_frame2,"Search")

    connect_button.connect(SEL_COMMAND) do
      connect_button_action
    end

    listButton.connect(SEL_COMMAND) do
      listButtonAction
    end

    pingButton.connect(SEL_COMMAND) do
      pingButtonAction
    end

    dumpButton.connect(SEL_COMMAND) do
      dumpButtonAction
    end

    searchButton.connect(SEL_COMMAND) do
      searchButtonAction
    end
  end

  def connect_button_action
    @txt.removeText(0,@txt.length)
    # @txt.appendText("Connect\n")
    # @txt.appendText("#{@server_field} #{@env_field} #{@port_field}")
    my_ip = GenIP.new(@myhash,@environments,@server_field.text,@env_field.text)
    if my_ip.valid then
      @txt.appendText("Connecting to #{my_ip.ip} on #{@port_field.text}\n")
      spawn @ssh_com+" #{@user}@#{my_ip.ip}"
    else
      @txt.appendText("Server or Environment not found.")
    end
  end

  def list_button_action
    @txt.removeText(0,@txt.length)
    @txt.appendText("Listing\n")
    my_ip = GenIP.new(@myhash,@environments,@server_field.text,@env_field.text)
    if my_ip.valid then
      @txt.appendText("Result : #{my_ip.ip} \n")
    else
      @txt.appendText("Server or Environment not found.")
    end
  end

  def ping_button_action
    @txt.removeText(0,@txt.length)
    @txt.appendText("Ping\n")
    my_ip = GenIP.new(@myhash,@environments,@server_field.text,@env_field.text)
    if my_ip.valid then
      @txt.appendText("Address : #{my_ip.ip}\n")
      stdout,stderr,status = Open3.capture3("ping -n 2 #{myIP.ip}")
      if status.success?
        @txt.appendText(stdout)
      else
        @txt.appendText(stderr)
      end
    else
      @txt.appendText("Server or Environment not found.")
    end
  end

  def dump_button_action
    @txt.removeText(0,@txt.length)
    @server_field.clearItems
    count = 1
    @myhash.each { |key, value|
      my_ip = GenIP.new(@myhash,@environments,key,@env_field.text)
      @server_field.appendItem(key)
      line = sprintf("%3d. %-13s = %-s",count,key,my_ip.ip)
      @txt.appendText("#{line}\n")
      count += 1
    }
  end

  def search_button_action
    @txt.removeText(0,@txt.length)
    @txt.appendText("Search\n")
    result = @myhash.keys.select{|i| i[Regexp.new @server_field.text]}
    if result.size != 0
      @txt.appendText("Details matching #{@server_field.text}\n")
      @server_field.clearItems
      counter = 0
      result.each {|key|
        my_ip = GenIP.new(@myhash,@environments,key,@env_field.text)
        @server_field.appendItem(key)
        line = sprintf("%3d. %-13s = %-s",counter+1,key,my_ip.ip)
        @txt.appendText("#{line}\n")
        counter +=1
      }
    else
      @txt.appendText("No details matching #{@server_field.text}\n")
    end
  end

  def add_new_server

  end

end

$app = FXApp.new
SimplePC.new($app, "Simple Putty Connector", 600, 400)
$app.create
$app.run
