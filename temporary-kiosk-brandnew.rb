#!/home/pi/.rvm/rubies/ruby-2.3.1/bin/ruby

require 'gtk3'
require 'net/ping'
# require './gtk_threads'
# require 'ruby-nfc'
require_relative 'ruby-nfc-1.3/lib/ruby-nfc'
require 'socket'
require './bidapp_api'
# require './tagreader'
require 'timeout'
require 'yaml'
require 'securerandom'
require 'open-uri'
require_relative 'biathlon_tag'

NUMBER, CHOICE = *(0..25).to_a
TSIGN = 'Ŧ'


def parse_yaml(file)
  YAML::load(File.open(file))
end

def check_api
 @config = parse_yaml('./config.yml')
 return Net::Ping::TCP.new(@config['api_server'],  @config['api_port'], 1).ping?
end 

def api_status_check(fixed)
  if fixed.nil?
    return
      p 'exiting subroutine'
  end

  status = check_api

  if @acb
    # @status_box.remove @acb
  end
  @acb = Gtk::Button.new label: 'Check API again'
  @status_box.remove @api_status
  if status == true
    @buttons.each do |button|
      button.sensitive = true
    end
    # @api_status = Gtk::Label.new 'API is reachable'
  else
    @buttons.each do |button|
      button.sensitive = false
    end
    @api_status = Gtk::Label.new "API is not reachable: #{@config['api_server']} port #{@config['api_port']}"
    @status_box.pack_start @acb, :expand => true, :fill => false, :padding =>2

    @acb.signal_connect 'clicked' do
      # @status_box.remove @acb
      api_status_check(fixed)
    end
  end
  @status_box.pack_start @api_status, :expand => true, :fill => false, :padding =>2
  fixed.show_all
  # GLib::Timeout.add(1000) do api_status_check(fixed) end
  while Gtk.events_pending? do
    Gtk.main_iteration
  end


end
 
 

  

  class BiathlonTill < Gtk::Application

    def init_ui
      @wrapper = Gtk::Box.new(:vertical, 0)


      @buttons = Array.new
      e_space = Gtk::Alignment.new 1, 1, 0, 0
      @wrapper.pack_start e_space, expand: false

      status = check_api
      if status == true
        @api_status = Gtk::Label.new 'API is reachable'
      else
        @api_status = Gtk::Label.new "API is not reachable: #{@config['api_server']} port #{@config['api_port']}"
      end
      @status_box = Gtk::Box.new(:horizontal, 5)
      # @status_box.parent = @wrapper
      @acb = Gtk::Button.new label: 'Check API again'
      @status_box.pack_start @acb, :expand => true, :fill => false, :padding =>2
      @status_box.pack_start @api_status, :expand => false, :fill => false, :padding => 2


      # @wrapper.pack_start @status_box, :expand => true, :fill => false, :padding =>2
      reapply_css(@wrapper)
      return @wrapper
    end
    
    def main_menu(window)
      if @wrapper
        window.remove(@wrapper)
        @wrapper.destroy
        puts 'making wrapper again'
        @wrapper = init_ui

        @wrapper.show_all
      end
      halign = Gtk::Alignment.new 1, 0, 0, 0
      @hbox = Gtk::Box.new(:horizontal, 5)
      lalign = Gtk::Alignment.new 0, 1, 0, 0
      @lbox = Gtk::Box.new(:horizontal, 5)
      halign.add  @hbox
      lalign.add @lbox
      @wrapper = init_ui unless @wrapper
      @wrapper.pack_start halign, :expand => false, 
          :fill => false, :padding => 5
      image = Gtk::Image.new(:file => "img/temporary_logo.png")
      @wrapper.pack_start image
      @events_button = Gtk::Button.new label: "Experiment check-in", name: 'wide'
      @events_button.set_size_request 70, 70
      @card_button = Gtk::Button.new label: "Card services"
      @card_button.set_size_request 70, 70
      @buttons.push(@events_button)
      @buttons.push(@card_button)
      @restart_button = Gtk::Button.new label: 'Restart'
      @restart_button.set_size_request 70, 70
      @lbox.pack_start @restart_button
      @wrapper.pack_start lalign , :expand => false,
          :fill => false, :padding => 5 
      window.set_default_size 800, 480
      window.add @wrapper
      status = check_api
      
      if status == true
        @api_status = Gtk::Label.new 'API is reachable'
        @events_button.sensitive = true
        @card_button.sensitive = true
      else
        @api_status = Gtk::Label.new "API is not reachable: #{@config['api_server']} port #{@config['api_port']}"
        @card_button.sensitive = false
        @events_button.sensitive = false
      
        
        @acb.signal_connect 'clicked' do
          self.destroy
        end

      end
      
      @events_button.signal_connect "clicked" do
        @wrapper.destroy
        events_menu(window)
      end
      @restart_button.signal_connect 'clicked' do
	@wrapper.destroy
        window.destroy
	 Gtk.main_quit
      end

      @card_button.signal_connect "clicked" do
        @wrapper.destroy
        card_services(window)
      end
      
      unless @api_status.nil?
        @wrapper.pack_start @api_status, expand: false, fill: false, padding: 5
      end
      unless @status_message.nil?
        status_label = Gtk::Label.new @status_message, name: 'status'
        @wrapper.pack_start status_label, expand: false, fill: false, padding: 50
      end
      @hbox.pack_start @events_button, :expand => false, :fill => false, :padding =>2
      @hbox.pack_start @card_button, :expand => false, :fill => false, :padding =>2

      
      reapply_css(@hbox)
      reapply_css(@lbox)
      reapply_css @wrapper
      window.show_all
    end
    
    
      
    def initialize
      @config = parse_yaml('config.yml')
      # EventMachine.start_server '127.0.0.1','8080', TillWrapper, 1
      super("org.gtk.exampleapp", :handles_open)
      provider = Gtk::CssProvider.new
      provider.load(:data => File.read("kiosk.css"))
      @reader = readers = NFC::Reader.all[0] 

      signal_connect "activate" do |application|

        window = BiathlonTillMain.new(application)
        window.decorated = false
        window.signal_connect("delete-event") { |_widget| Gtk.main_quit }



        # GLib::Timeout.add(1000) do api_status_check(window) end
        while Gtk.events_pending? do
          Gtk.main_iteration
        end
        
        apply_css(window, provider)
        events_menu(window)
        window.show_all
      end
      
    end
  
    def apply_css(widget, provider)
      widget.style_context.add_provider(provider, GLib::MAXUINT)
      if widget.is_a?(Gtk::Container)
        widget.each_all do |child|
          apply_css(child, provider)
        end
      end
    end
     
    def reapply_css(element)
      provider = Gtk::CssProvider.new
      provider.load(:data => File.read("kiosk.css"))
      apply_css(element, provider)  
    end
    
    def events_menu(fixed)
      if @wrapper
        fixed.remove(@wrapper)
        @wrapper.destroy
        puts 'making wrapper again'
        @wrapper = init_ui

        
      end
      @wrapper = init_ui unless @wrapper
      
      status = check_api
      
      if status == true
        @api_status = Gtk::Label.new 'API is reachable'
      else
        @api_status = Gtk::Label.new "API is not reachable: #{@config['api_server']} port #{@config['api_port']}"
      end
      
      image = Gtk::Image.new(:file => "img/temporary_logo.png")
      @wrapper.pack_start image
      # get today's events
      api = BidappApi.new
      events = api.api_call('/events/today', {})
      if events['error']
        @api_status = events['error']
      elsif events['data'].empty?
        @api_status = 'No activities today, sorry!'
      else
        event_buttons = []

        events['data'].each_with_index do |e, i|
          event_buttons[i] = Gtk::Button.new label: e['attributes']['name'] + " (#{e['attributes']['cost-bb']}#{TSIGN})"
          # p "attempting to get URL #{e['attributes']['image']['image']['thumb']['url']}"
          # p "and write to local file img/tmp/#{File.basename(e['attributes']['image']['image']['thumb']['url'])}"
          begin
            File.open("img/tmp/#{File.basename(e['attributes']['image']['image']['thumb']['url'])}", 'wb') do |fo|
              fo << URI.join(e['attributes']['image']['image']['thumb']['url'].gsub(/development/, 'production')).read 
            end
            event_buttons[i].set_image Gtk::Image.new(file: "img/tmp/#{File.basename(e['attributes']['image']['image']['thumb']['url'])}")
          rescue
            event_buttons[i].set_image  Gtk::Image.new(file: "img/missing_user.png")
          end
          event_buttons[i].set_image_position :left
          
         
          # event_buttons[i].set_size_request 50, 80
          @wrapper.pack_start event_buttons[i], expand: false, fill: true, padding: 10
          event_buttons[i].signal_connect "clicked" do
            fixed.remove @wrapper
            event_checkin(e, fixed)
          end
        end
      end
      cancel_button = Gtk::Button.new label: 'Re-query events'
      cancel_button.signal_connect "clicked" do
        fixed.remove @wrapper
        puts 'back to main menu'
        events_menu(fixed)
      end
      cancel_button.set_size_request 70, 70
      @wrapper.pack_start cancel_button, expand: false, fill: false, padding: 5
      fixed.add @wrapper
      reapply_css(@wrapper)
      fixed.show_all 
    end
    
    def print_onetimer(event, onetimer, window, button)
      pf = IO.sysopen('/dev/ttyUSB0', 'w+')
      printer = IO.new(pf)
      printer.puts "Welcome to Temporary\n\n\nYou have participated in:\n\n  #{event['title']}\n\n\nYour entry code is:  #{onetimer['data']['attributes']['code']}\n\n\nRedeem this code at\n www.temporary.fi\n\n\n\n\n\n" 
     
      printer.close
      md = Gtk::MessageDialog.new :parent => self, buttons_type: :yes_no,
                 :flags => :destroy_with_parent, :type => :question, 
                 :message => "Did the tag print OK?"
      md.transient_for = window
      md.set_default_size(300, 300)


      md.signal_connect("response") do |widget, response|
        case response
        when -8
          button.sensitive = true
          md.destroy
        when -9
          md.destroy
          print_onetimer(event,onetimer, window, button)
        else
          p "dialog response is " + response.inspect + " from widget " + widget.inspect
        end
      end
      md.run
      # md.show_all
      
    end
    
    def event_checkin(event, window, tag_id = nil)
      # @wrapper = init_ui
      tag = ''
      api = BidappApi.new
      @wrapper = Gtk::Box.new :horizontal, 0
      
      left_wrapper = Gtk::Box.new :vertical, 5
      left_wrapper.set_size_request 500, 480
      right_wrapper = Gtk::Box.new :vertical, 5
      title_wrapper = Gtk::Box.new :horizontal, 5
      top_icon = Gtk::Image.new(file: "img/tmp/#{File.basename(event['attributes']['image']['image']['thumb']['url'])}")
      titlev = Gtk::Box.new :vertical, 5

      top_title = Gtk::Label.new event['attributes']['name']
      top_temps = Gtk::Label.new event['attributes']['cost-bb'].to_s + "#{TSIGN}"
      title_wrapper.pack_start top_icon
      titlev.pack_start top_title  
      titlev.pack_start top_temps
      title_wrapper.pack_start titlev
      
      
      main_return_area = Gtk::Box.new :horizontal
      
      info_box = Gtk::TextView.new
      info_box.buffer.text = "\nWaiting for reader....\n"

      scrolled_win = Gtk::ScrolledWindow.new
      scrolled_win.border_width = 3
      scrolled_win.min_content_width = 200
      scrolled_win.min_content_height = 280
      scrolled_win.add(info_box)
      scrolled_win.set_size_request 200, 280

      

      # right_vbox = Gtk::Box.new :vertical, 5

    

      
      # right_vbox.pack_start temporary_button, expand: false, fill: false, padding: 15

      hbox = BiathlonTag.new 
      # hbox.pack_start scrolled_win, expand: false, fill: false, padding: 15
      # hbox.pack_start right_vbox, expand: false, fill: false, padding: 15
      cancel_button = Gtk::Button.new label: 'Change experiment'
      cancel_button.set_size_request 50, 50
      guest_ticket = Gtk::Button.new label: 'Print guest ticket'
      guest_ticket.set_size_request 100, 50
            

      
      left_wrapper.pack_start title_wrapper, expand: false, fill: false, padding: 10
      left_wrapper.pack_start main_return_area
      right_wrapper.pack_start cancel_button, expand: false, fill: false, padding: 15
      right_wrapper.pack_start scrolled_win
      right_wrapper.pack_start guest_ticket

      @wrapper.pack_start left_wrapper, expand: true, fill: false, padding: 0
      @wrapper.pack_start right_wrapper, expand: true, fill: false, padding: 0

      
      window.signal_connect("delete-event") { |_widget| Gtk.main_quit }
      
      window.add @wrapper
      reapply_css(@wrapper)
      window.show_all
      
      while (Gtk.events_pending?)
        Gtk.main_iteration
      end

      thread =  Thread.new { hbox.read_tag(@reader) }
      # p 'thread is ' + thread.inspect
      
      cancel_button.signal_connect "clicked" do
        window.remove @wrapper
        thread.kill
        events_menu(window)
      end

      guest_ticket.signal_connect "clicked" do
        guest_ticket.sensitive = false
        if info_box.buffer.text == "\nWaiting for reader....\n"
          info_box.buffer.text = ''
        end
        onetimer = api.api_call("/instances/#{event['id']}/onetimer", {})
        info_box.buffer.text = "\nGenerated guest code: #{onetimer['data']['attributes']['code']}" + info_box.buffer.text 
        window.remove @wrapper
        left_wrapper.remove main_return_area
        main_return_area = nil
        main_return_area = Gtk::Box.new :vertical
        onetimer_label = Gtk::Label.new "Guest code is:"
        guest_code = Gtk::Label.new onetimer['data']['attributes']['code']
        guest_code.set_name 'guest_code'
        main_return_area.pack_start onetimer_label
        main_return_area.pack_start guest_code
        left_wrapper.pack_start main_return_area
        @wrapper.pack_start left_wrapper, expand: true, fill: false, padding: 0
        @wrapper.pack_start right_wrapper
        window.add @wrapper
        window.show_all
        reapply_css(@wrapper)
        while (Gtk.events_pending?)
          Gtk.main_iteration
        end
        if onetimer['error']
          info_box.buffer.text = "\nError generating guest code: #{onetimer['error'].inspect}" + info_box.buffer.text 
        else
          print_onetimer(event, onetimer, window, guest_ticket)
        end
        
      end
 
            
      hbox.signal_connect("read_tag") do |obj, tag|
        if tag == 'Mifare error'
          info_box.buffer.text = "\nError reading card - please try again!\n" + info_box.buffer.text
          while (Gtk.events_pending?)
            Gtk.main_iteration
          end
     
        else
          # clear info box
          if info_box.buffer.text == "\nWaiting for reader....\n"
            info_box.buffer.text = ''
          end
          (tag_address, secret)= tag.split(/---/)
  
          info_box.buffer.text = "\nRead card with id #{tag_address}" +  info_box.buffer.text
        
          while (Gtk.events_pending?)
            Gtk.main_iteration
          end
          
          puts "will send tag id #{tag_address} with key #{secret}"
          info_box.buffer.text = "\nLooking for user ..." +  info_box.buffer.text
          userinfo = api.api_call("/nfcs/#{tag_address}/user_from_tag", {securekey: secret})
          while (Gtk.events_pending?)
            Gtk.main_iteration
          end
          if userinfo['data']
            
            username = userinfo['data']['attributes']['username']
            real_name = userinfo['data']['attributes']['name']
            info_box.buffer.text = "\nFound user #{userinfo['data']['attributes']['username']}" +  info_box.buffer.text
            while (Gtk.events_pending?)
              Gtk.main_iteration
            end
          elsif userinfo['error']
            info_box.buffer.text =  "\nError: " + userinfo['error'].inspect +  info_box.buffer.text

          end

          if username.nil? && tag != ''
            info_box.buffer.text = "\nNo user found for tag #{tag_address} {debug: #{userinfo.inspect}}" + info_box.buffer.text
            window.remove @wrapper
            left_wrapper.remove main_return_area
            
            main_return_area = nil
            main_return_area = Gtk::Box.new :vertical
            new_card_label = Gtk::Label.new 'Blank card - link to new user?'
            main_return_area.pack_start new_card_label 
            
            a = look_for_users(main_return_area, window, event)
            search_interface = a.first
            entry = a.last
            while (Gtk.events_pending?)
              Gtk.main_iteration
            end
            
            main_return_area.remove new_card_label
            left_wrapper.pack_start title_wrapper, expand: false, fill: false, padding: 10
            main_return_area.pack_start search_interface
            left_wrapper.pack_start main_return_area
            
            @wrapper.pack_start left_wrapper, expand: true, fill: false, padding: 0
            @wrapper.pack_start right_wrapper
            window.add @wrapper
            window.show_all
            reapply_css(@wrapper)
            entry.set_can_focus true
            entry.grab_focus
            while (Gtk.events_pending?)
              Gtk.main_iteration
            end

            
          elsif tag != ''
            info_box.buffer.text = "\nSubmitting check-in to blockchain (please wait a few seconds...)" + info_box.buffer.text
            while (Gtk.events_pending?)
              Gtk.main_iteration
            end
            puts "/users/#{userinfo['data']['id']}/instances/#{event['id']}/user_attend"
            check_in = api.api_call("/users/#{userinfo['data']['id']}/instances/#{event['id']}/user_attend", {})
            if check_in['error']
              if check_in['error'].empty?
                info_box.buffer.text = "\n\nError: Ethereum client is likely down, please try again in 5 seconds " + info_box.buffer.text 
              elsif check_in['error'].nil?
                info_box.buffer.text = "\n\nError: Ethereum client is likely down, please try again in 5 seconds " + info_box.buffer.text 
              else
                info_box.buffer.text = "\n\n#{check_in['error']['base'].join(' / ')}" + info_box.buffer.text 
                # window.remove @wrapper
                
                left_wrapper.remove main_return_area
                main_return_area = nil
                main_return_area = Gtk::Box.new :vertical
                outer_user_box = user_info_onscreen(userinfo)
                
                main_return_area.pack_start outer_user_box
                error_msg = Gtk::Label.new check_in['error']['base'].join(' / ')
                error_msg.set_name "error_red"
                main_return_area.pack_start error_msg
                
                left_wrapper.pack_start main_return_area
                @wrapper.pack_start left_wrapper, expand: true, fill: false, padding: 0
                @wrapper.pack_start right_wrapper
                window.add @wrapper
                window.show_all
                reapply_css(@wrapper)
                while (Gtk.events_pending?)
                  Gtk.main_iteration
                end
              end
             
            else
              info_box.buffer.text = "\n\nChecked in user #{real_name.to_s} (#{username}) to event \n'#{event['title']}' (+#{event['attributes']['cost-bb']}#{TSIGN})" + info_box.buffer.text  
              # window.remove @wrapper
              left_wrapper.remove main_return_area
              main_return_area = nil
              main_return_area = Gtk::Box.new :vertical
              outer_user_box = user_info_onscreen(userinfo)
 
              main_return_area.pack_start outer_user_box
              success_msg = Gtk::Label.new "Checked in!"
              temps_msg = Gtk::Label.new "You will receive #{event['attributes']['cost-bb']}#{TSIGN}."
              success_msg.set_name "success_msg"
              temps_msg.set_name "temps_msg"
              main_return_area.pack_start success_msg
              main_return_area.pack_start temps_msg
              left_wrapper.pack_start main_return_area
              @wrapper.pack_start left_wrapper, expand: true, fill: false, padding: 0
              @wrapper.pack_start right_wrapper
              window.add @wrapper
              window.show_all
              reapply_css(@wrapper)
              while (Gtk.events_pending?)
                Gtk.main_iteration
              end
            end
           
          else
            info_box.buffer.text = "\n\nCan't find a user linked to tag #{tag_address}" + info_box.buffer.text 
            while (Gtk.events_pending?)
              Gtk.main_iteration
            end
           
          end



          while (Gtk.events_pending?)
            Gtk.main_iteration
          end
         
        end
       t = Thread.new{  hbox.read_tag(@reader)  }
      end
    
    end
    
    
    def look_for_users(main_return_area, window, event)
      return_box = Gtk::Box.new :vertical
      
      search_box = Gtk::Box.new :horizontal
      search_title = Gtk::Label.new 'Search for a name:', name: '#search'
      entry = Gtk::Entry.new
      search_box.pack_start search_title,  :expand => false, :fill => false, :padding => 5
      search_box.pack_start entry, :expand => false, :fill => false, :padding => 5

      # main_return_area.pack_start search_box
      searchbutton = Gtk::Button.new label: "Search!"
      searchbutton.set_size_request 70, 70
      
      return_box.pack_start search_box
      return_box.pack_start searchbutton


      searchbutton.signal_connect "clicked" do

        this_box = Gtk::Box.new :vertical

        query = search_users(entry.text, window, event)
        
        

        
        
        if query == false
          no_results = Gtk::Label.new 'No search results, please try again.'          
          this_box.pack_start no_result          
        else
          this_box.pack_start query.first
          
          back_button = query[1]
          back_button.signal_connect "clicked" do
            p 'pushed cancel button'
            main_return_area.remove this_box
            
            window.add main_return_area
            reapply_css(@wrapper)
            window.show_all
            while (Gtk.events_pending?)
              Gtk.main_iteration
            end
            t = Thread.new{  main_return_area.read_tag(@reader)  }
          end
          user_list_tree = query[3]
          user_list = query[4]
          link_button = query[2]
          link_button.signal_connect("clicked") do |link|
            p 'pushed linked button'

            tag_window = BiathlonTag.new 
            tag = Thread.new{ tag_window.write_tag(@reader) }
            while (Gtk.events_pending?)
              Gtk.main_iteration
            end
          
            tag_window.signal_connect("write_tag") do |obj,  tag|
              p 'got to write tag callback'
              if tag.nil?
                p 'tag is nil'
              elsif tag == 'Mifare error'
                @status_message = 'Error reading tag (because they are cheap), please try again. Sorry!'
                main_return_area.remove this_box

                
              elsif tag.length > 4
                p user_list['data'][user_list_tree.selection.selected[0].to_i-1]['attributes']['slug']
                puts "URL would be #{@config['api_url']}/users/#{user_list['data'][user_list_tree.selection.selected[0].to_i-1]['attributes']['slug']}/link_to_nfc"

                (tag_id, secret) = tag.split(/---/)
                puts "with post data of tag " + tag_id + ' and secret ' + secret
                api = BidappApi.new
                r = api.link_tag("/users/#{user_list['data'][user_list_tree.selection.selected[0].to_i-1]['attributes']['slug']}/link_to_nfc",  tag_id, secret)
                # p "r is " + r.inspect
                if r['error']
                  @status_message = r['error']
                elsif r['data']
                  @status_message = 'Linked user ' + user_list['data'][user_list_tree.selection.selected[0].to_i-1]['attributes']['username'] + ' to id card #' + tag_id.to_s
                end
                main_return_area.remove this_box
              end
            end
          end
          
        end
        main_return_area.remove return_box
        main_return_area.pack_start this_box
        window.add main_return_area
        reapply_css(@wrapper)
        window.show_all
        while (Gtk.events_pending?)
          Gtk.main_iteration
        end
      end

      return [return_box, entry]
    end
    
    def user_info_onscreen(user)
      outer_user_box = Gtk::Box.new :horizontal
      if user['data']
        
        
        userbox = Gtk::Box.new :vertical
        userbox.set_name 'check_in'
        username = Gtk::Label.new "Username: " + user['data']['attributes']['username']
        username.set_justify :left
        if user['data']['attributes']['name']
          name = Gtk::Label.new "Name: " + user['data']['attributes']['name']
        else
          name = Gtk::Label.new 'Real name unknown'
        end
        name.set_justify :left
        member_since = Gtk::Label.new "Member since: " + user['data']['attributes']['created-at']
        member_since.set_justify :left
        balance = Gtk::Label.new "Latest balance: #{user['data']['attributes']['latest-balance']}#{TSIGN}"
        balance.set_justify :left
        events_attended = Gtk::Label.new "Activities attended: #{user['data']['attributes']['events-attended']}"
        events_attended.set_justify :left
        if user['data']['attributes']['last-attended']
          last_attended =  Gtk::Label.new "Last attended: #{user['data']['attributes']['last-attended']['title']}"
          last_at =  Gtk::Label.new "Last seen at: #{user['data']['attributes']['last-attended-at']}"
        else
          last_attended =  Gtk::Label.new "No activities attended yet."
          last_at = Gtk::Label.new ""
        end
        last_attended.set_justify :left
        last_at.set_justify :left
        
        # get image
        if user['data']['attributes']['avatar']['avatar']['thumb']['url'] == '/assets/transparent.gif'
          image = Gtk::Image.new(:file => "img/missing_user.png")
        else
          p "attempting to get URL #{user['data']['attributes']['avatar']['avatar']['thumb']['url']}"
          p "and write to local file img/tmp/#{File.basename(user['data']['attributes']['avatar']['avatar']['thumb']['url'])}"
          begin
            File.open("img/tmp/#{File.basename(user['data']['attributes']['avatar']['avatar']['thumb']['url'])}", 'wb') do |fo|
              fo << URI.join(user['data']['attributes']['avatar']['avatar']['thumb']['url'].gsub(/development/, 'production')).read 
            end
            image = Gtk::Image.new(:file => "img/tmp/#{File.basename(user['data']['attributes']['avatar']['avatar']['thumb']['url'])}")
          rescue
            image = Gtk::Image.new(:file => "img/missing_user.png")
          end
        end

        
        userbox.pack_start username
        userbox.pack_start name
        userbox.pack_start member_since
        userbox.pack_start events_attended
        userbox.pack_start balance
        userbox.pack_start last_attended
        userbox.pack_start last_at
        outer_user_box.pack_start userbox
        outer_user_box.pack_start image
      else
        error = Gtk::Label.new 'Error reading user info'
        outer_user_box.pack_start error
      end
      return outer_user_box
    end
    
    
    
    def tag_loop(reader,  info_box)
      tagreader = BiathlonTag.new
      tag = nil
      while tag.nil? do
        tag = tagreader.read_tag(reader)
      end
      if tag == ''
        p 'tag is nil'
      elsif tag.length > 4
        p 'taggin is ' + tag.inspect
        info_box.buffer.text = 'tag is ' + tag.inspect
        
      end
      return tag
    end
      
    def erase_card(fixed)
      @wrapper = init_ui
      label = Gtk::Label.new 'Hold card over reader (below screen, over the wood above the black printer)...'
      label2 = Gtk::Label.new 'This will erase the card so it can be re-linked to a user.'
      
      ebox = BiathlonTag.new
      t =  Thread.new { ebox.erase_tag(@reader)  }
      
      @wrapper.pack_start label, expand: false, fill: false, padding: 15 
      @wrapper.pack_start label2, expand: false, fill: false, padding: 15 
   
      ebox.signal_connect("erase_tag") do |obj, tag|
        (tag_address, secret) = tag.split(/---/)
        p 'got signal of tag ' + tag_address + ' with secret ' + secret
        api = BidappApi.new
        erase = api.api_call('/nfcs/' + tag_address + '/erase_tag', {})
        p 'erasing hopefully ' + "/nfcs/#{tag_address}/erase_tag"
        if erase['data']
          @status_message = erase['data']['tag_address'] + " has been deleted"
        else
          @status_message = erase['error']
        end       
        fixed.remove @wrapper
        main_menu(fixed)

      end  
          
      reapply_css(@wrapper)
      fixed.add @wrapper
      fixed.show_all
    end
          
    def card_info(fixed)
      @wrapper = init_ui
      label = Gtk::Label.new 'Hold card over reader (below screen, over the wood above the black printer)...'
      @wrapper.pack_start label, expand: false, fill: false, padding: 15    
      
      hbox = BiathlonTag.new
      t = Thread.new { hbox.read_tag(@reader)  }

      response_label = nil
      outer_user_box = nil
      api = BidappApi.new
      hbox.signal_connect("read_tag") do |obj, tag|
        fixed.remove @wrapper
        unless response_label.nil?
          begin
            @wrapper.remove response_label 
          rescue Exception => e
            p e
          end
          unless outer_user_box.nil?
            @wrapper.remove outer_user_box
          end
        end
        if tag == 'Mifare error'
          response_label = Gtk::Label.new "Error reading card - please try again!"
          
        else
          (tag_address, secret)= tag.split(/---/)
          response_label = Gtk::Label.new "Card has id##{tag_address.to_s}"
          userinfo = api.api_call("/nfcs/#{tag_address}/user_from_tag", {securekey: secret})
          while Gtk.events_pending? do
            Gtk.main_iteration
          end
          if userinfo['data']
            outer_user_box = Gtk::Box.new :horizontal
            
            userbox = Gtk::Box.new :vertical
            username = Gtk::Label.new "Username: " + userinfo['data']['attributes']['username']
            if userinfo['data']['attributes']['name']
              name = Gtk::Label.new "Name: " + userinfo['data']['attributes']['name']
            else
              name = Gtk::Label.new 'Real name unknown'
            end
            member_since = Gtk::Label.new "Member since: " + userinfo['data']['attributes']['created-at']
            balance = Gtk::Label.new "Latest balance: #{userinfo['data']['attributes']['latest-balance']}#{TSIGN}"
            events_attended = Gtk::Label.new "Activities attended: #{userinfo['data']['attributes']['events-attended']}"
            if userinfo['data']['attributes']['last-attended']
              last_attended =  Gtk::Label.new "Last attended: #{userinfo['data']['attributes']['last-attended']['title']}"
              last_at =  Gtk::Label.new "Last seen at: #{userinfo['data']['attributes']['last-attended-at']}"
            else
              last_attended =  Gtk::Label.new "No activities attended yet."
              last_at = Gtk::Label.new ""
            end
            
            # get image
            if userinfo['data']['attributes']['avatar']['avatar']['medium']['url'] == '/assets/transparent.gif'
              image = Gtk::Image.new(:file => "img/missing_user.png")
            else
              p "attempting to get URL #{userinfo['data']['attributes']['avatar']['avatar']['small']['url']}"
              p "and write to local file img/tmp/#{File.basename(userinfo['data']['attributes']['avatar']['avatar']['small']['url'])}"
              begin
                File.open("img/tmp/#{File.basename(userinfo['data']['attributes']['avatar']['avatar']['small']['url'])}", 'wb') do |fo|
                  fo << URI.join(userinfo['data']['attributes']['avatar']['avatar']['small']['url'].gsub(/development/, 'production')).read 
                end
                image = Gtk::Image.new(:file => "img/tmp/#{File.basename(userinfo['data']['attributes']['avatar']['avatar']['small']['url'])}")
              rescue
                image = Gtk::Image.new(:file => "img/missing_user.png")
              end
            end
            
            userbox.pack_start username
            userbox.pack_start name
            userbox.pack_start member_since
            userbox.pack_start events_attended
            userbox.pack_start balance
            userbox.pack_start last_attended
            userbox.pack_start last_at
            outer_user_box.pack_start image
            outer_user_box.pack_start userbox
            @wrapper.pack_start outer_user_box
            reapply_css(@wrapper)
            while Gtk.events_pending? do
              Gtk.main_iteration
            end
          end
        end
        @wrapper.pack_start response_label 
        fixed.add @wrapper
        fixed.show_all
        while Gtk.events_pending? do
          Gtk.main_iteration
        end
        t =  Thread.new { hbox.read_tag(@reader)  }
      end
      
      cancel_button = Gtk::Button.new label: 'Return to main menu'
      cancel_button.signal_connect "clicked" do
        
        t.kill
        hbox.destroy
        fixed.remove @wrapper
        puts 'back to main menu'
        main_menu(fixed)
      end
      cancel_button.set_size_request 70, 60
      @wrapper.pack_start cancel_button, expand: false, fill: false, padding: 15
      
      reapply_css(@wrapper)
      fixed.add @wrapper
      fixed.show_all
    end
    
    def card_services(fixed)
      @wrapper = init_ui
      cbuttons = []
      cbuttons[0] = Gtk::Button.new label: 'Check card info'
      cbuttons[0].set_size_request 50, 60
      cbuttons[0].signal_connect 'clicked' do
        fixed.remove @wrapper
        card_info(fixed)
      end

      cbuttons[1] = Gtk::Button.new label: 'Link user to new card'
      cbuttons[1].set_size_request 50, 60
      cbuttons[1].signal_connect 'clicked' do
        fixed.remove @wrapper
        link_card(fixed)
      end
      cbuttons[2] = Gtk::Button.new label: 'Erase card'
      cbuttons[2].set_size_request 50, 60
      cbuttons[2].signal_connect 'clicked' do
        fixed.remove @wrapper
        erase_card(fixed)
      end
      cbuttons.each do |cb|
        @wrapper.pack_start cb, expand: false, fill: false, padding: 15
      end
      cancel_button = Gtk::Button.new label: 'Return to main menu'
      cancel_button.signal_connect "clicked" do
        fixed.remove @wrapper
        puts 'back to main menu'
        main_menu(fixed)
      end
      cancel_button.set_size_request 70, 60
      @wrapper.pack_start cancel_button, expand: false, fill: false, padding: 15
      fixed.add @wrapper
      reapply_css(@wrapper)
      fixed.show_all 
    end

    def link_card(fixed)  
      @w = init_ui
      hbox = Gtk::Box.new(:horizontal, 5)

      title = Gtk::Label.new 'Search for users without cards', name: '#search'
      entry = Gtk::Entry.new
      @w.pack_start title,  :expand => false, :fill => false, :padding => 5
      @w.pack_start entry, :expand => false, :fill => false, :padding => 5
      
      entry.set_can_focus true

      searchbutton = Gtk::Button.new label: "Search!"
      searchbutton.set_size_request 70, 70
      hbox.pack_start searchbutton,  :expand => false, :fill => false, :padding => 5

      cancel_button = Gtk::Button.new label: 'Return to main menu'
      cancel_button.set_size_request 70, 70
      @buttons.push(cancel_button)
      @buttons.push(searchbutton)
      
      cancel_button.signal_connect "clicked" do
        fixed.remove @w
        main_menu(fixed)
      end
      
      hbox.pack_start cancel_button, :expand => false, :fill => false, :padding => 5
      # add fixed
      @w.pack_start hbox, :expand => false, :fill => false, :padding => 5
    
      searchbutton.signal_connect "clicked" do
        fixed.remove @w
        @w = init_ui
        vbox = search_users(entry.text, fixed)
        @w.add vbox
        fixed.add @w
        fixed.show_all
      end
      
      reapply_css(@w)
      while (Gtk.events_pending?)
        Gtk.main_iteration
      end
      fixed.add @w
      entry.grab_focus
      fixed.show_all
      
    end  
    
    
    
    def on_key_release sender, event, label
        label.set_text sender.text
    end
  
  
    def setup_list_view(listview)
      renderer = Gtk::CellRendererText.new
      renderer.foreground = "#ff0000"
      column   = Gtk::TreeViewColumn.new( "Num",  renderer, {text: NUMBER})
      listview.append_column(column) 
      renderer = Gtk::CellRendererText.new
      column   = Gtk::TreeViewColumn.new("Count", renderer,  {text: CHOICE})
      listview.append_column(column)
    end
    

      
    def search_users(searchterm, fixed, event)
      puts "Searching server for '#{searchterm}'"
      api = BidappApi.new
      user_list = api.api_call('/nfcs/unattached_users', {q: searchterm})
      if user_list['data'].empty?

        return false
      else
        user_array = []
        user_list['data'].each do |u|
          user_array.push([u['id'], "#{u['attributes']['username']} / #{u['attributes']['name']} <#{u['attributes']['email']}>"])
        end
        user_list_tree = Gtk::TreeView.new
        setup_list_view(user_list_tree)
        store = Gtk::ListStore.new(Integer, String)
        choice_window = Gtk::Window.new

        id_link  = Gtk::Label.new("Select an account")
        vbox = Gtk::Box.new :vertical, 0
        hbox = Gtk::Box.new :horizontal, 10
        vbox.pack_start id_link, expand: false, fill: false, padding: 10
        user_list['data'].each_with_index do |e,i|
          iter = store.append
          iter[NUMBER]   = i + 1
          iter[CHOICE] = "#{user_list['data'][i]['attributes']['username']} / #{user_list['data'][i]['attributes']['name']} <#{user_list['data'][i]['attributes']['email']}>"
        end

        user_list_tree.model = store
        scrolled_win = Gtk::ScrolledWindow.new
        scrolled_win.add(user_list_tree)
        scrolled_win.set_size_request 400, 160
        # scrolled_win.set_policy(Gtk::POLICY_AUTOMATIC, Gtk::POLICY_AUTOMATIC)
        vbox.pack_start(scrolled_win, expand: false, fill: false, padding: 10)
      
        link_button = Gtk::Button.new label: 'Link'
        back_button = Gtk::Button.new label: 'Cancel'
        link_button.set_size_request 70, 70
        back_button.set_size_request 70, 70


      


      
        hbox.pack_start(link_button, expand: false, fill: true, padding: 15)
        hbox.pack_start(back_button, expand: false, fill: true, padding: 15)
        vbox.pack_start hbox, expand: true, fill: true, padding: 15
        while (Gtk.events_pending?)
          Gtk.main_iteration
        end
        return [vbox, back_button, link_button, user_list_tree, user_list]
      end
    end
   
  end
  
  class BiathlonTillMain  < Gtk::ApplicationWindow
     
    def initialize(application)
       super(application)
       set_border_width 10
    end
    
  end
  
  



window = BiathlonTill.new
window.run
# Gtk.main
