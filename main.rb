require 'dry/container'


module Models
    class Task
        attr_reader :id
        attr_accessor :text, :priority

        def initialize(id:, text:, priority:)
            @id = id
            @text = text
            @priority = priority
        end
    end
    
    class Priority
        attr_reader :value
        
        LOW = 0
        MEDIUM = 1
        HIGH = 2

        ALL = [LOW, MEDIUM, HIGH]

        def initialize(value)
            raise "Invalid priority value." unless ALL.include?(value)
            @value = value
        end

        public
        
        def max?
            @value == HIGH
        end

        def min?
            @value == LOW
        end

        def up
           return self if max?

           self.class.new(@value + 1)
        end

        def down
           return self if min?

           self.class.new(@value - 1)
        end

        def self.low
            self.new LOW
        end
    end
end


module Enumerators
    class Simple
        @@_n = 0

        public

        def call
            @@_n += 1
        end
    end
end


module Factories
    class Task
        def initialize(enumerator:)
            @enumerator = enumerator
        end

        def call(text:, priority:)
            task_id = @enumerator.call

            Models::Task.new(
                id: task_id,
                text: text,
                priority: priority,
            )
        end
    end
end


module Repositories
    class Tasks
        def initialize
            @tasks = []
        end

        public

        # commands

        def add(task)
            @tasks.push(task)
        end
        
        def remove_by_id(task_id)
            @tasks = @tasks.select { |task| task.id != task_id }
        end

        # queries

        def list
            @tasks.sort_by { |task| task.priority.value }.reverse
        end

        def find_by_id(task_id)
            @tasks.detect { |task| task.id == task_id }
        end
    end
end


module TaskPrinters
    class Base
        public
        
        def call(task)
            raise NotImplementedError, 'Provide implementation for #call'
        end
    end

    class Plain < Base
        public
        
        def call(task)
            "- #{task.id}: #{task.text}"
        end
    end
    
    class Csv < Base
        public

        def call(task)
            "#{task.id},#{task.text},#{task.priority.value}"
        end
    end
end


module UseCases
    class PrintTasks
        def initialize(task_printer:, tasks_repository:)
            @task_printer = task_printer
            @tasks_repository = tasks_repository
        end
        
        public
        
        def call
            @tasks_repository.list.each do |task|
                output = @task_printer.call(task)

                puts output
            end
        end
    end

    class AddTask
        def initialize(task_factory:, tasks_repository:)
            @task_factory = task_factory
            @tasks_repository = tasks_repository
        end

        public
        
        def call(text)
            task = @task_factory.call(
                text: text,
                priority: Models::Priority.low
            )

            @tasks_repository.add(task)
        end
    end
    
    class RemoveTask
        def initialize(tasks_repository:)
            @tasks_repository = tasks_repository
        end

        def call(task_id)
            @tasks_repository.remove_by_id(task_id)
        end
    end

    class EditTask
        def initialize(tasks_repository:)
            @tasks_repository = tasks_repository
        end

        def call(task_id:, text:)
            task = @tasks_repository.find_by_id(task_id)
            return if task.nil?

            task.text = text
        end
    end

    class UpTask
        def initialize(tasks_repository:)
            @tasks_repository = tasks_repository
        end

        def call(task_id:)
            task = @tasks_repository.find_by_id(task_id)
            return if task.nil?

            task.priority = task.priority.up
        end
    end

    class DownTask
        def initialize(tasks_repository:)
            @tasks_repository = tasks_repository
        end

        def call(task_id:)
            task = @tasks_repository.find_by_id(task_id)
            return if task.nil?

            task.priority = task.priority.down
        end
    end
end


module Container
    def self.build
        container = Dry::Container.new

        container.namespace('todo') do
            register(:simple_enumerator, memoize: true) do
                Enumerators::Simple.new
            end

            register(:task_factory, memoize: true) do
                Factories::Task.new(
                    enumerator: resolve(:simple_enumerator),
                )
            end

            register(:tasks_repository, memoize: true) do
                Repositories::Tasks.new
            end

            register(:plain_printer, memoize: true) do
                TaskPrinters::Plain.new
            end

            register(:csv_printer, memoize: true) do
                TaskPrinters::Csv.new
            end

            register(:print_tasks) do
                UseCases::PrintTasks.new(
                    tasks_repository: resolve(:tasks_repository),
                    task_printer: resolve(:plain_printer),
                )
            end

            register(:add_task) do
                UseCases::AddTask.new(
                    tasks_repository: resolve(:tasks_repository),
                    task_factory: resolve(:task_factory),
                )
            end

            register(:remove_task) do
                UseCases::RemoveTask.new(
                    tasks_repository: resolve(:tasks_repository),
                )
            end

            register(:edit_task) do
                UseCases::EditTask.new(
                    tasks_repository: resolve(:tasks_repository),
                )
            end

            register(:up_task) do
                UseCases::UpTask.new(
                    tasks_repository: resolve(:tasks_repository),
                )
            end

            register(:down_task) do
                UseCases::DownTask.new(
                    tasks_repository: resolve(:tasks_repository),
                )
            end
        end
    end
end


if __FILE__ == $0
    container = Container.build

    add_task = container.resolve('todo.add_task')
    print_tasks = container.resolve('todo.print_tasks')
    remove_task = container.resolve('todo.remove_task')
    edit_task = container.resolve('todo.edit_task')
    up_task = container.resolve('todo.up_task')
    down_task = container.resolve('todo.down_task')

    puts 'Create 2 tasks:'

    add_task.call('A task example!')
    add_task.call('Another task!')
    up_task.call(task_id: 1)
    print_tasks.call

    puts 'Edit task:'

    edit_task.call(task_id: 1, text: 'Text updated!')
    print_tasks.call

    puts 'Increase priority:'

    up_task.call(task_id: 2)
    print_tasks.call

    puts 'Removing a task:'

    remove_task.call(1)
    print_tasks.call
end
