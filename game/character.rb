# abilities
# character#leveling
#   perhaps fib (10, 20, 30, 50... or ditto*10)
# building#upgrades
# tech tree style upgrades
# buffs/debuffs
# hero vs unit

class Model

  def self.abilities
    @abilities ||=
      if superclass.respond_to?(:abilities)
        superclass.abilities.dup
      else
        {}
      end
  end

  def self.attributes
    @attributes ||=
      if superclass.respond_to?(:attributes)
        superclass.attributes.dup
      else
        {}
      end
  end

  def self.ability(name, options={})
    class_eval <<-EOS, __FILE__, __LINE__
      def #{name}
        instance_eval(&self.class.abilities[:#{name}][:block])
      end
    EOS
    abilities[name] ||= {}
    abilities[name] = abilities[name].merge(options)
  end

  def self.attribute(name, options={})
    class_eval <<-EOS, __FILE__, __LINE__
      attr_accessor :#{name}
      private :#{name}=
    EOS
    attributes[name] ||= {}
    attributes[name] = attributes[name].merge(options)
  end

  def initialize(attributes={})
    for key, value in self.class.attributes
      send(:"#{key}=", value[:default]) if value[:default]
    end
    update(attributes)
  end

  def update(attributes={})
    for key, value in attributes
      send("#{key}=", value)
    end
  end

end

class Character < Model

  attribute :brawn,       :default => 1
  attribute :brains,      :default => 1
  attribute :experience,  :default => 0
  attribute :health,      :default => 100
  attribute :level,       :default => 1

end

class Warrior < Character

  ability   :yell,        :block => lambda { p 'ARGH!' }
  attribute :brawn,       :default => 2

end

class Wizard < Character

  attribute :brains,      :default => 2

end

p Warrior.new
p Warrior.new.yell
p Wizard.new
