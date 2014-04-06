module ApplicationHelper
  def menu_header
    menu_items = Refinery::Menu.new(Refinery::Page.menu_pages)

    presenter = Refinery::Pages::MenuPresenter.new(menu_items, self)
    presenter.first_css = nil
    presenter.last_css = nil

    presenter
  end
end