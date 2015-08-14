#!/usr/bin/ruby
# cg.rb
# Simply Putty Connection Manger
# Alastair Montgomery 2014

require 'yaml'
require 'fox16'
require 'pp'
require 'open3'
include Fox

require File.expand_path(File.join(File.dirname(__FILE__), "lib/GenIP"))

class SimplePC < FXMainWindow
  def initialize(app, title, w, h)

    #Load static data
    @myhash   = YAML::load_file(File.expand_path(File.join(File.dirname(__FILE__), 'details.yaml')))
    @environments     = YAML::load_file(File.expand_path(File.join(File.dirname(__FILE__), 'envs.yaml')))
    settings = YAML::load_file(File.expand_path(File.join(File.dirname(__FILE__), 'settings.yaml')))

    @user = settings['user']
    @profile = settings['profile']
    @sshcom = settings['app'] + " " + settings['profile']

    #Setup GUI
    super(app, title, :width => w, :height => h)
    add_menu_bar
    @hFrame1 = FXHorizontalFrame.new(self)
    @hFrame2 = FXHorizontalFrame.new(self)
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
    chrLabel = FXLabel.new(@hFrame1,"Server")
    # @serverField = FXTextField.new(@hFrame1,15)
    @serverField = FXComboBox.new(@hFrame1,20,:opts => FRAME_SUNKEN|FRAME_THICK)
    chrLabel = FXLabel.new(@hFrame1,"Environment")
    @envField  = FXComboBox.new(@hFrame1,8,:opts => FRAME_SUNKEN|FRAME_THICK)
    @envField.fillItems(@environments.keys)
    chrLabel = FXLabel.new(@hFrame1,"Port")
    @portField = FXTextField.new(@hFrame1,4)
    @portField.text = "22"
  end

  def add_buttons
    connectButton = FXButton.new(@hFrame2,"Connect")
    listButton = FXButton.new(@hFrame2,"List")
    pingButton = FXButton.new(@hFrame2,"Ping")
    dumpButton = FXButton.new(@hFrame2,"Dump")
    searchButton = FXButton.new(@hFrame2,"Search")

    connectButton.connect(SEL_COMMAND) do
      connectButtonAction
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

  def connectButtonAction
    @txt.removeText(0,@txt.length)
    # @txt.appendText("Connect\n")
    # @txt.appendText("#{@serverField} #{@envField} #{@portField}")
    myIP = GenIP.new(@myhash,@environments,@serverField.text,@envField.text)
    if myIP.valid then
      @txt.appendText("Connecting to #{myIP.ip} on #{@portField.text}\n")
      spawn @sshcom+" #{@user}@#{myIP.ip}"
    else
      @txt.appendText("Server or Environment not found.")
    end
  end

  def listButtonAction
    @txt.removeText(0,@txt.length)
    @txt.appendText("Listing\n")
    myIP = GenIP.new(@myhash,@environments,@serverField.text,@envField.text)
    if myIP.valid then
      @txt.appendText("Result : #{myIP.ip} \n")
    else
      @txt.appendText("Server or Environment not found.")
    end
  end

  def pingButtonAction
    @txt.removeText(0,@txt.length)
    @txt.appendText("Ping\n")
    myIP = GenIP.new(@myhash,@environments,@serverField.text,@envField.text)
    if myIP.valid then
      @txt.appendText("Address : #{myIP.ip}\n")
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

  def dumpButtonAction
    @txt.removeText(0,@txt.length)
    @serverField.clearItems
    count = 1
    @myhash.each { |key, value|
      myIP = GenIP.new(@myhash,@environments,key,@envField.text)
      @serverField.appendItem(key)
      line = sprintf("%3d. %-13s = %-s",count,key,myIP.ip)
      @txt.appendText("#{line}\n")
      count += 1
    }
  end

  def searchButtonAction
    @txt.removeText(0,@txt.length)
    @txt.appendText("Search\n")
    result = @myhash.keys.select{|i| i[Regexp.new @serverField.text]}
    if result.size != 0
      @txt.appendText("Details matching #{@serverField.text}\n")
      @serverField.clearItems
      counter = 0
      result.each {|key|
        myIP = GenIP.new(@myhash,@environments,key,@envField.text)
        @serverField.appendItem(key)
        line = sprintf("%3d. %-13s = %-s",counter+1,key,myIP.ip)
        @txt.appendText("#{line}\n")
        counter +=1
      }
    else
      @txt.appendText("No details matching #{@serverField.text}\n")
    end
  end

  def addNewServer

  end

end

$app = FXApp.new
SimplePC.new($app, "Simple Putty Connector", 600, 400)
$app.create
$app.run
