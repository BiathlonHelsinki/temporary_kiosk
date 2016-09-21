#!/home/pi/.rvm/rubies/ruby-2.3.1/bin/ruby

require 'gtk3'
# require './gtk_threads'
# require 'ruby-nfc'
require_relative 'ruby-nfc-1.3/lib/ruby-nfc'
require 'socket'
require './bidapp_api'
# require './tagreader'
require 'eventmachine'
require 'timeout'
require 'yaml'
require 'securerandom'
require_relative 'biathlon_tag'

NUMBER, CHOICE = *(0..25).to_a



def parse_yaml(file)
  YAML::load(File.open(file))
end

 
 
class TillWrapper < EventMachine::Connection
  

  class BiathlonTill < Gtk::Window

    def initialize
      @config = parse_yaml('config.yml')
      EventMachine.start_server '127.0.0.1','8080', TillWrapper, 1
      @reader = readers = NFC::Reader.all[0]
      super
      provider = Gtk::CssProvider.new
      provider.load(:data => File.read("kiosk.css"))

      apply_css(self, provider)
      main_menu
    end
    
    def apply_css(widget, provider)
         widget.style_context.add_provider(provider, GLib::MAXUINT)
         if widget.is_a?(Gtk::Container)
             widget.each_forall do |child|
                 apply_css(child, provider)
             end
         end
     end
    
    
    def main_menu
      fixed = Gtk::Fixed.new
      
      events_button = Gtk::Button.new label: "Experiment check-in"
      
      card_button = Gtk::Button.new label: "Card services"
      fixed.put events_button, 10, 40
      fixed.put card_button, 200, 40
      set_default_size 750, 450
      set_window_position :center

        fixed.signal_connect("delete-event") { |_widget| Gtk.main_quit }
        
        events_button.signal_connect "clicked" do
          fixed.destroy
          events_menu
        end
        
        
        card_button.signal_connect "clicked" do
          fixed.destroy
          card_services
        end
        add fixed
        
        show_all     
    end
    
    def events_menu
      fixed = Gtk::Fixed.new
      
      # get today's events
      api = BidappApi.new
      events = api.api_call('/events/today', {})
      if events['error']
        fixed.put Gtk::Label.new(events['error']), 50, 50
      elsif events['data'].empty?
        fixed.put Gtk::Label.new('No events, sorry'), 50, 50
      else
        event_buttons = []
        events['data'].each_with_index do |e, i|
          event_buttons[i] = Gtk::Button.new label: e['title']
          fixed.put event_buttons[i], 50, 40*(i+1)
          event_buttons[i].signal_connect "clicked" do
            fixed.destroy
            event_checkin(e)
          end
        end
      end
      cancel_button = Gtk::Button.new label: 'Return to main menu'
      cancel_button.signal_connect "clicked" do
        fixed.destroy
        main_menu
      end
      fixed.put cancel_button, 20, 100
      add fixed
      show_all 
    end
    
    def event_checkin(event)

      tag = ''
      api = BidappApi.new
      fixed = BiathlonTag.new
      cancel_button = Gtk::Button.new label: 'Return to main menu!'
      title = Gtk::Label.new 'Hold card over reader to check in'
    
      cancel_button.signal_connect "clicked" do
        fixed.destroy
        main_menu
      end
    
      temporary_button = Gtk::Button.new label: 'Print guest ticket'

    
      info_box = Gtk::TextView.new
      info_box.buffer.text = "\nWaiting for reader....\n"

      scrolled_win = Gtk::ScrolledWindow.new
      scrolled_win.border_width = 3
      scrolled_win.min_content_width = 650
      scrolled_win.min_content_height = 250
      scrolled_win.add(info_box)
  
      fixed.put scrolled_win, 20, 200
      fixed.put title, 20, 20
      fixed.put cancel_button, 20, 100
      fixed.put temporary_button, 45, 150

      fixed.signal_connect("delete-event") { |_widget| Gtk.main_quit }
      
      add fixed
      show_all
      
      while (Gtk.events_pending?)
        Gtk.main_iteration
      end

      EM.defer { fixed.read_tag(@reader) }
      

      temporary_button.signal_connect "clicked" do
        if info_box.buffer.text == 'Waiting for reader...'
          info_box.buffer.text = ''
        end
        onetimer = api.api_call("/instances/#{event['id']}/onetimer", {})

        if onetimer['error']
          info_box.buffer.text = "\nError generating temporary code: #{onetimer['error'].inspect}" + info_box.buffer.text 
        else
          pf = IO.sysopen('/dev/ttyUSB0', 'w+')
          printer = IO.new(pf)
          printer.puts "Welcome to Temporary\n\n\nYou have participated in:\n\n  #{event['title']}\n\n\nYour entry code is:  #{onetimer['data']['attributes']['code']}\n\n\nRedeem this code at\n www.temporary.fi\n\n\n\n\n\n" 
          info_box.buffer.text = "\nGenerated temporary code: #{onetimer['data']['attributes']['code']}" + info_box.buffer.text 
          printer.close
        end
      end
 
            
      fixed.signal_connect("read_tag") do |obj, tag|
        # clear info box
        if info_box.buffer.text == 'Waiting for reader...'
          info_box.buffer.text = ''
        end
        (tag_address, secret)= tag.split(/---/)
  
        # get tag info
        # api = BidappApi.new
        puts "will send tag id #{tag_address} with key #{secret}"

        userinfo = api.api_call("/nfcs/#{tag_address}/user_from_tag", {securekey: secret})

        if userinfo['data']
          username = userinfo['data']['attributes']['username']
          real_name = userinfo['data']['attributes']['name']
        elsif userinfo['error']
          info_box.buffer-text = "\n" + userinfo['error']
        end

        if (real_name.nil? || username.nil?) && tag != ''
          info_box.buffer.text = "\nNo user found for tag #{tag_address}" + info_box.buffer.text + "\n"
        elsif tag != ''
          puts "/users/#{userinfo['data']['id']}/instances/#{event['id']}/user_attend"
          check_in = api.api_call("/users/#{userinfo['data']['id']}/instances/#{event['id']}/user_attend", {})
          if check_in['error']
            info_box.buffer.text = "\nError checking in: #{check_in['error']['base'].join(' / ')}" + info_box.buffer.text + "\n"
          else
            info_box.buffer.text = "\nChecking in user #{real_name} (#{username}) to event '#{event['name']}" + info_box.buffer.text  + "\n"
          end
        else
          info_box.buffer.text = "\nCan't find a user linked to tag #{tag_address}" + info_box.buffer.text + "\n"
        end


        t =  EM.defer { fixed.read_tag(@reader) }

      end

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
      
      
    def card_services  
      fixed = Gtk::Fixed.new
      title = Gtk::Label.new 'Search for users without cards'
      entry = Gtk::Entry.new
      fixed.put entry, 60, 40
      fixed.put entry, 60, 100

      searchbutton = Gtk::Button.new label: "Search!"
      fixed.put searchbutton, 60, 150

      add fixed
      
      searchbutton.signal_connect "clicked" do
        vbox = search_users(entry.text)
        remove fixed
        add vbox
        show_all
      end
                
      set_title "Biathlon Till"
      signal_connect "destroy" do 
          Gtk.main_quit 
      end        

      set_default_size 250, 200
      set_window_position :center
      
      show_all        
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
    
    
    
    def search_users(searchterm)
      puts "Searching server for '#{searchterm}'"
      api = BidappApi.new
      user_list = api.api_call('/nfcs/unattached_users', {q: searchterm})

      user_array = []
      user_list['data'].each do |u|

        user_array.push([u['id'], "#{u['attributes']['username']} / #{u['attributes']['name']} <#{u['attributes']['email']}>"])
      end
      user_list_tree = Gtk::TreeView.new
      setup_list_view(user_list_tree)
      store = Gtk::ListStore.new(Integer, String)
      choice_window = Gtk::Window.new

      id_link  = Gtk::Label.new("Select an account to link ID card to, put card over reader, and click *Link*")
      vbox = Gtk::Box.new :vertical, 2
      vbox.pack_start id_link, expand: false, fill: false, padding: 10
      user_list['data'].each_with_index do |e,i|
        iter = store.append
        iter[NUMBER]   = i + 1
        iter[CHOICE] = "#{user_list['data'][i]['attributes']['username']} / #{user_list['data'][i]['attributes']['name']} <#{user_list['data'][i]['attributes']['email']}>"
      end

      user_list_tree.model = store
      scrolled_win = Gtk::ScrolledWindow.new
      scrolled_win.add(user_list_tree)
      # scrolled_win.set_policy(Gtk::POLICY_AUTOMATIC, Gtk::POLICY_AUTOMATIC)
      vbox.pack_start(scrolled_win, expand: true, fill: true, padding: 10)
      
      link_button = Gtk::Button.new label: 'Link'
      back_button = Gtk::Button.new label: 'Back'

      back_button.signal_connect "clicked" do
        vbox.destroy
        card_services
      end
      
      link_button.signal_connect("clicked") do |link|
        tag_window = BiathlonTag.new
        nwl = Gtk::Label.new('Put the card up')

        tag_window.put nwl, 20, 20
        while (Gtk.events_pending?)
          Gtk.main_iteration
        end
 
        tag_window.signal_connect("write_tag") do |obj,  tag|
          if tag.nil?
            p 'tag is nil'

          elsif tag.length > 4
            p user_list['data'][user_list_tree.selection.selected[0].to_i-1]['attributes']['slug']
            puts "URL would be #{@config['api_url']}/users/#{user_list['data'][user_list_tree.selection.selected[0].to_i-1]['attributes']['slug']}/link_to_nfc"

            (tag_id, secret) = tag.split(/---/)
            puts "with post data of tag " + tag_id + ' and secret ' + secret
            api = BidappApi.new
            api.link_tag("/users/#{user_list['data'][user_list_tree.selection.selected[0].to_i-1]['attributes']['slug']}/link_to_nfc",  tag_id, secret)
            vbox.destroy
            main_menu

          end
        end
        
        t =  Thread.new { tag = tag_window.write_tag(@reader) }
        t.join
      end
      
      vbox.pack_start(link_button, expand: false, fill: true, padding: 15)
      vbox.pack_start(back_button, expand: false, fill: true, padding: 15)
      return vbox
    end
   
  end
  
end


EventMachine.run {



  
  window = TillWrapper::BiathlonTill.new
  give_tick = proc { Gtk::main_iteration_do(false);
       EM.next_tick(give_tick); }
  give_tick.call
}

# Gtk.main_with_queue(100)
