#encoding: utf-8

require 'awesome_print'
require 'watir-webdriver'
require 'watir-dom-wait'
require 'yaml'

watir = YAML.load_file("#{ARGV[0]}")

Watir::Dom::Wait.timeout  = 1
Watir::Dom::Wait.delay    = 1
Watir::Dom::Wait.interval = 0.15


#globales
$proxy = ''
$proxy = watir['conf']['proxy'] if not watir['conf']['proxy'].nil?
$debug = false
$debug = watir['conf']['debug'] if not watir['conf']['debug'].nil?
$close = false
$close = watir['conf']['close'] if not watir['conf']['close'].nil?
$no_proxy = ''
$no_proxy = watir['conf']['no_proxy'] if not watir['conf']['no_proxy'].nil?
$host = watir['conf']['host']

class Wy
  def log(elem, text = '')
    if $debug
      puts ""
      puts ""
      puts "---------------"
      puts "#{text}|#{elem.class}|"
        puts "---------------"
      case elem.class.to_s
      when 'Array'
        ap elem 
      else
        puts elem.class.to_s
        puts elem.to_yaml
      end
      puts "---------------"
    end
  end

  def get_browser( proxy_url = '', no_proxy = '', profile_name = 'watir')
    if profile_name.nil?
      profile = Selenium::WebDriver::Firefox::Profile.new
    else
      profile = Selenium::WebDriver::Firefox::Profile.from_name 'watir'
    end

    extension = "#{Dir.pwd}/extensions/autoauth-2.1-fx+fn.xpi"
    if File.exists? extension
      profile.add_extension "#{Dir.pwd}/extensions/autoauth-2.1-fx+fn.xpi"
    end

    if proxy_url == ''
      ENV['HTTP_PROXY'] = ENV['http_proxy'] = nil
      browser = Watir::Browser.new :ff, :profile => profile
    else
      if no_proxy.nil?
        proxy = Selenium::WebDriver::Proxy.new(:http => proxy_url)
      else
        proxy = Selenium::WebDriver::Proxy.new(:http => proxy_url, :no_proxy => "#{no_proxy}")
      end
      ENV['HTTP_PROXY'] = ENV['http_proxy'] = nil
      browser = Watir::Browser.new :ff, :proxy => proxy, :profile => profile
    end
    browser
  end


  def process_actions(browser, actions)
    log actions, 'process_actions'
    if actions.has_key? 'url'
      browser.goto actions['url']
    elsif actions.has_key? 'window'
      browser.window(:title => actions['window'] ).use
    end

    if actions.has_key? 'actions'
      actions['actions'].each do |action|
        process_action(browser, action)
      end
    end
    browser
  end

  def process_action(browser, action)
    k,v = action.first
    case v['type']
    when 'fill'
      fill_element(browser, v)
    when 'select'
      select_element(browser, v)
    when 'autofill'
      autofill_element(browser, v)
    when 'click'
      click_element(browser, v)
    when 'read'
      read_element(browser, v)
    when 'close'
      close_element(browser, v)
    else
      log v['type'], 'process_action: type'
    end
  end

  def select_element(browser, action)
    log action, 'select_element'
    conf = action['conf'] unless action['conf'].nil?
    element = action['element']
    el = locate_element(browser, element)
    if not el.nil?
      case element['type']
      when 'radio'
        if action['value']
          el.set
        else
          el.clear 
        end
      when 'checkbox'
        if action['value']
          el.select
        else
          el.clear 
        end
      else
        if action['value']
          el.select 
        else
          el.clear 
        end
      end
    end
  end

  def close_element(browser, action)
    log action, 'close_element'
    conf = action['conf'] unless action['conf'].nil?
    element = action['element']
    case element['type']
    when 'window'
      win = locate_element(browser, element)
      win.close
    else
      els = locate_element(browser, element)
      els.each do |el|
        el.text
        el.name
        el.id
      end
    end
  end

  def read_element(browser, action)
    log action, 'read_element'
    conf = action['conf'] unless action['conf'].nil?
    element = action['element']
    case element['type']
    when 'text_fields'
      read_text_fields(browser)
    when 'select_lists'
      read_select_lists(browser)
    else
      els = locate_element(browser, element)
      els.each do |el|
        el.text
        el.name
        el.id
      end
    end
  end

  def autofill_element(browser, action)
    element = action['element']
    case element['type']
    when 'text_fields'
      autofill_text_fields(browser, action)
    when 'select_lists'
      autofill_select_lists(browser, action)
    else
      log element, "autofill"
    end
  end

  def autofill_text_fields(browser, action = nil)
    browser.text_fields.each do |txt|
      if txt.visible? and not txt.disabled?
        txt.set txt.name
      end
    end
  end

  def autofill_select_lists(browser, action = nil)
    exclude = action['exclude'] if not action.nil?
    log exclude, "excluidos"
    browser.selects.each do |slct|
      ap slct.name
      if slct.visible? and slct.enabled? and slct != nil
        opciones = slct.options.map(&:text)
        log opciones
        option = ""
        begin
          option = opciones.sample(1).join("")
          log option
        end while option == "" or option == nil or (not exclude.nil? and exclude.include? option)
        slct.select option
      end
    end
  end

  def read_select_lists(browser)
    browser.select_lists.each do |lst|
      log lst.value, 'seleccionado'
      lst.selected_options.each do |selected|
        log selected.text, 'texto de la opción'
        if selected.text != ''
          puts %{
      - action:
          type: 'fill'
          element: 
            type: 'select_list'
            locator: 'name'
            locate: '#{lst.name}'
          value: '#{selected.text}'
          }
        end
      end
    end
  end

  def read_text_fields(browser)
    browser.text_fields.each do |txt|
      if txt.value != ''
        puts %{
      - action:
          type: 'fill'
          element: 
            type: 'text_field'
            locator: 'name'
            locate: '#{txt.name}'
          value: '#{txt.value}'
        }
      end
    end
  end

  def fill_element(browser, action)
    log action, 'fill_element'
    conf = action['conf'] unless action['conf'].nil?
    element = action['element']
    el = locate_element(browser, element)
    if not el.nil? and el.visible?
      case element['type']
      when 'select_list'
        el.select action['value']
      else
        el.set action['value']
      end
    end
  end

  def click_element(browser, action)
    log action, 'click_element'
    conf = action['conf'] unless action['conf'].nil?
    element = action['element']
    wait_new_window = 0
    windows = [browser.windows.first.title]
    windows_count = browser.windows.count
    if (not conf.nil? and conf['wait_new_window'].nil?) 
      wait_new_window = conf['wait_new_window'].to_i
      current_window = previous_window = browser.windows.first.title
      log current_window, 'current window'
    end


    log windows_count, 'windows_count'
    el = locate_element(browser, element)
    if not el.nil?
      #log el, "element located"
      if el.visible?
        el.click
        log windows, 'Windows'
        new_windows = []
        if wait_new_window > 0
          begin
            sleep 1
            windows = browser.windows.map{|window| window.title}
            new_windows = windows - [current_window]
          end while windows_count == browser.windows.count
          log new_windows, 'new_windows'
        end
      end
    end
    log windows, 'Windows'
    log new_windows, 'new_windows'
    browser
  end

  def locate_element(browser, element)
    log element, 'locate_element'
    case element['type']
    when 'link'
      browser.link :"#{element['locator']}" => element['locate']
    when 'span'
      browser.span :"#{element['locator']}" => element['locate']
    when 'div'
      browser.div :"#{element['locator']}" => element['locate']
    when 'button'
      browser.button :"#{element['locator']}" => element['locate']
    when 'text_field'
      browser.text_field :"#{element['locator']}" => element['locate']
    when 'text_fields'
      #browser.text_fields
      txts = browser.input :type => 'text', :"#{element['locator']}" => element['locate']
      pwds = browser.input :type => 'password', :"#{element['locator']}" => element['locate']
      (txts|pwds)
    when 'select_list'
      browser.select_list :"#{element['locator']}" => element['locate']
    when 'radio'
      browser.radio :"#{element['locator']}" => element['locate']
    when 'window'
      browser.window :"#{element['locator']}" => element['locate']
    else
      browser.element :"#{element['locator']}" => element['locate']
    end
  end
end

wy = Wy.new
b = wy.get_browser($proxy, $no_proxy)
ARGV.each do |arg|
  watir = YAML.load_file("#{arg}")
  watir['watir'].each do |step|
    k,v = step.first
    b.driver.manage.timeouts.implicit_wait = 3 #wait
    case v['type']
    when 'login'
      b = wy.login_to(b, v)
    when 'form'
      wy.fill_form(b, v)
    when 'actions'
      wy.process_actions(b, v)
    else
      wy.log k, 'step'
    end
  end
end

at_exit { b.close if $close and b }
