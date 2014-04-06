Refinery::Page.class_eval do
  def self.menu_pages
    where :show_in_menu => true
  end
end