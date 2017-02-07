
class BiathlonTag < Gtk::Dialog
  type_register

  signal_new("write_tag",              # name
         GLib::Signal::RUN_FIRST, # flags
         nil,                     # accumulator (XXX: not supported yet)
         nil,
         Array 
   )
   
   signal_new("read_tag",              # name
          GLib::Signal::RUN_FIRST, # flags
          nil,                     # accumulator (XXX: not supported yet)
          nil,
          Array 
    )
    
    signal_new("erase_tag",              # name
           GLib::Signal::RUN_FIRST, # flags
           nil,                     # accumulator (XXX: not supported yet)
           nil,
           Array 
     )    
  def signal_do_read_tag(tag)
    return tag
  end
   
  def signal_do_erase_tag(tag)
    return tag
  end
    
  def signal_do_write_tag(tag)
   return tag
  end
   
  def erase_tag(reader, thread)
      p '-e-e-e-e-erase-thread id is ' + thread.inspect

       reader.poll(Mifare::Classic::Tag, Mifare::Ultralight::Tag) do |tag|
         begin

            case tag
            when Mifare::Classic::Tag
              if tag.auth(4, :key_a, "FFFFFFFFFFFF")
                p "Contents of block 0x04: #{tag.read.unpack('H*').pop}"
                rnd = Array.new(16).map{rand(255)}.pack('C*')
                tag.write(rnd)
                p "New value: #{rnd.unpack('H*').pop}"

                @tag = tag.uid_hex + '---' + rnd.unpack('H*').pop
                puts 'tag id is ' + tag.uid_hex + ' and tag is ' + rnd.unpack('H*').pop
              end
              if !@tag.nil?
                if @tag.length > 4
                  break
                end
              end
            when Mifare::Ultralight::Tag
              tag_id = tag.read(0).unpack('H*').pop + tag.read(1).unpack('H*').pop + tag.read(2).unpack('H*').pop
              p '7-byte tag erase is  ' + tag_id.to_s.gsub(/\d{4$}/, '')
              tag.write('00000000', 4)
              @tag = tag_id.to_s.gsub(/0000$/, '') +  '---' + '0000'
              p 'erasing tag: ' + @tag.to_s
              unless @tag.nil?
                if @tag.length > 4
                  break
                end
              end
          end
        rescue Exception => e
          @tag = e
          p e.inspect
          break
        end
      end

     if @tag.class == Mifare::Error
       p 'Mifare error'
       self.erase_tag(reader, thread)
     else
       self.signal_emit("erase_tag", [@tag, thread])
     end
  end
   
    
  def write_tag(reader, thread)
   
    p '-w-w-w-w-thread id is ' + thread.inspect
  
       reader.poll(Mifare::Classic::Tag, Mifare::Ultralight::Tag) do |tag|
         begin

            case tag
            when Mifare::Classic::Tag
              if tag.auth(4, :key_a, "FFFFFFFFFFFF")
                p "Contents of block 0x04: #{tag.read.unpack('H*').pop}"
                rnd = Array.new(16).map{rand(255)}.pack('C*')
                tag.write(rnd)
                p "New value: #{rnd.unpack('H*').pop}"

                @tag = tag.uid_hex + '---' + rnd.unpack('H*').pop
                puts 'tag id is ' + tag.uid_hex + ' and tag is ' + rnd.unpack('H*').pop
              end
              if !@tag.nil?
                if @tag.length > 4
                  break
                end
              end
            when Mifare::Ultralight::Tag
              tag_id = tag.read(0).unpack('H*').pop + tag.read(1).unpack('H*').pop + tag.read(2).unpack('H*').pop
              p '7-byte tag write is  ' + tag_id.to_s.gsub(/\d{4$}/, '')
              rnd = SecureRandom.hex(4)
              tag.write(rnd, 4)
              @tag = tag_id.to_s.gsub(/0000$/, '') +  '---' + rnd
              p 'writing tag: ' + @tag.to_s
              unless @tag.nil?
                if @tag.length > 4
                  break
                end
              end
          end
        rescue Exception => e
          @tag = e
          p "error here: " + e.inspect
          break
        end
        
      end
     #
     #
     # }
     # t.join
     if @tag.class == Mifare::Error
       p 'got to this error stage'
       @tag = 'Mifare error'
       self.write_tag(reader, thread)
     else
       p '@tag set to ' + @tag.inspect
       self.signal_emit("write_tag", [@tag, thread])
     end
     
   
   end
   
   def read_tag(reader, thread)
     # t = Thread.new {
     #
     reader.poll(Mifare::Classic::Tag, Mifare::Ultralight::Tag) do |tag|
       begin

          case tag
            when Mifare::Classic::Tag
              if tag.auth(4, :key_a, "FFFFFFFFFFFF")
                p "Contents of block 0x04: #{tag.read.unpack('H*').pop}"
                @tag = tag.uid_hex + '---' + tag.read.unpack('H*').pop
                puts 'read tag id is ' + @tag
              end
              if !@tag.nil?
                if @tag.length > 4
                  break
                end
              end
            when Mifare::Ultralight::Tag
              tag_id = tag.read(0).unpack('H*').pop + tag.read(1).unpack('H*').pop + tag.read(2).unpack('H*').pop
              p '7-byte tag is ' + tag_id.to_s.gsub(/\d{4$}/, '')

              @tag = tag_id.to_s.gsub(/0000$/, '') +  '---' + tag.read(4).unpack('H*').pop
              p 'reading tag: ' + @tag.to_s
              unless @tag.nil?
                if @tag.length > 4
                  break
                end
              end
          end
        rescue Exception => e
            @tag = e
            p 'got exception reading ' + e.inspect
            self.read_tag(reader, thread)
            
        end

      end
      begin
      if @tag.class == Mifare::Error
        @tag = 'Mifare error'
      elsif !@tag.nil?
        self.signal_emit("read_tag", [@tag, thread])
      else
        exit
      end
     rescue NoMethodError => e
       p 'rescuing here: ' + e.inspect + ' and tag ' + @tag.inspect
     rescue TypeError => e
       p 'rescuing type error: ' + e.inspect + ' and tag ' + @tag.inspect
     end
     p '------thread id is ' + thread.inspect
   
   end
   
   
  
   def initialize
     
     super
     @tag = nil
   end
  
  
   def tag
     @tag
   end
  
   def tag=(arg)
     puts "tag= is called"
     @tag = arg
   end
   
   install_property(GLib::Param::String.new("thread", # name
                                         "Thread", # nick
                                         "a thread object #", # blurb
                                         '0',     # default
                                         GLib::Param::READABLE |
                                         GLib::Param::WRITABLE))
   
   install_property(GLib::Param::String.new("tag", # name
                                         "Tag", # nick
                                         "a random string", # blurb
                                         '0',     # default
                                         GLib::Param::READABLE |
                                         GLib::Param::WRITABLE))

 end
 